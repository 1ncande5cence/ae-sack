/*
  Copyright 2015 Google LLC All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/*
   american fuzzy lop - LLVM-mode instrumentation pass
   ---------------------------------------------------

   Written by Laszlo Szekeres <lszekeres@google.com> and
              Michal Zalewski <lcamtuf@google.com>

   LLVM integration design comes from Laszlo Szekeres. C bits copied-and-pasted
   from afl-as.c are Michal's fault.

   This library is plugged into LLVM when invoking clang through afl-clang-fast-indirect.
   It tells the compiler to add code roughly equivalent to the bits discussed
   in ../afl-as.h.
*/

#define AFL_LLVM_PASS

#include "../config.h"
#include "../debug.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <map>
#include <vector>

#include <string.h>
#include "sys/stat.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/DebugInfo.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

#include "llvm/IR/Dominators.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"

using namespace llvm;

namespace {

  class AFLCoverage : public ModulePass {

    public:

      static char ID;
      AFLCoverage() : ModulePass(ID) { }

      bool runOnModule(Module &M) override;


      // StringRef getPassName() const override {
      //  return "American Fuzzy Lop Instrumentation";
      // }

  };

}

FILE *line_log;
FILE *address_log;
FILE *fptr_cmp_log;

#define LINE_LOG_FILE       "./log/line_log"
#define FPTR_CMP_LOG_FILE   "./log/fptr_cmp_log"
#define ADDRESS_LOG_FILE    "./log/address_log"
#define BB_LOG_FILE         "./log/bb_log"

char AFLCoverage::ID = 0;
int counter, counter_null, counter_FUNC;


#include <iostream>
static inline bool is_llvm_dbg_intrinsic(Instruction& instr)
{
  const bool is_call = instr.getOpcode() == Instruction::Invoke ||
    instr.getOpcode() == Instruction::Call;
  if(!is_call) { return false; }

  // CallSite cs(&instr);
  auto call = dyn_cast<CallInst>(&instr);
  // Function* calledFunc = cs.getCalledFunction();
  Function* calledFunc = call->getCalledFunction();

  if (calledFunc != NULL) {
    const bool ret = calledFunc->isIntrinsic() &&
      calledFunc->getName().startswith("llvm.");
    return ret;
  } else {
    /*if (!isa<Constant>(cs.getCalledValue())){
      llvm::outs() << ">>> inst : \n";
      instr.dump();
      cs.getCalledValue()->getType()->dump();
      }
      Constant* calledValue = cast<Constant>(cs.getCalledValue());
      GlobalValue* globalValue = cast<GlobalValue>(calledValue);
      Function *f = cast<Function>(globalValue);

      const bool ret = f->isIntrinsic() &&
      starts_with(globalValue->getName().str(), "llvm.");
      return ret;*/
    return false;
  }
}


bool isFuncPtrTy(Type *type) {
  if (type->isPointerTy()) {
    Type *pointeeType = type->getPointerElementType();
    return pointeeType->isFunctionTy();
  }
  return false;
}

bool isCastedFromFuncPtr(Value * val) {

  if (BitCastInst * BCI = dyn_cast<BitCastInst>(val)) {
    Type * srcTy = BCI->getSrcTy();
    if (isFuncPtrTy(srcTy))
      return true;
  }

  return false;
}


bool AFLCoverage::runOnModule(Module &M) {

  LLVMContext &C = M.getContext();
  errs() << M.getName() << "\n";
  errs() << M.getSourceFileName() << "\n";
  IntegerType *Int8Ty  = IntegerType::getInt8Ty(C);
  IntegerType *Int32Ty = IntegerType::getInt32Ty(C);
  IntegerType *Int64Ty = IntegerType::getInt64Ty(C);
  PointerType *Int8PtrTy = Type::getInt8PtrTy(C);
  Type *VoidTy = Type::getVoidTy(C);

  /* Show a banner */

  char be_quiet = 0;

  if (isatty(2) && !getenv("AFL_QUIET")) {

    SAYF(cCYA "afl-llvm-pass " cBRI VERSION cRST " by <lszekeres@google.com>\n");

  } else be_quiet = 1;

  /* Decide instrumentation ratio */

  char* inst_ratio_str = getenv("AFL_INST_RATIO");
  unsigned int inst_ratio = 100;

  if (inst_ratio_str) {

    if (sscanf(inst_ratio_str, "%u", &inst_ratio) != 1 || !inst_ratio ||
        inst_ratio > 100)
      FATAL("Bad value of AFL_INST_RATIO (must be between 1 and 100)");

  }

  /* Get globals for the SHM region and the previous location. Note that
     __afl_prev_loc is thread-local. */

  GlobalVariable *AFLMapPtr =
      new GlobalVariable(M, PointerType::get(Int8Ty, 0), false,
                         GlobalValue::ExternalLinkage, 0, "__afl_area_ptr");

  GlobalVariable *AFLPrevLoc = new GlobalVariable(
      M, Int32Ty, false, GlobalValue::ExternalLinkage, 0, "__afl_prev_loc",
      0, GlobalVariable::GeneralDynamicTLSModel, 0, false);

  /* Instrument all the things! */

  /* Prepare for the function insertion*/

  uint64_t icall_id = 0;
  uint64_t jump_collect = 0;
  uint64_t asm_inside = 0;
  std::vector<Type *> args = {Int64Ty, Int64Ty};
  std::vector<Type *> args_mem = {Int64Ty, Int64Ty};
  std::vector<Type *> log_args = {Int32Ty};
  std::vector<Type *> modify_args = {Int8PtrTy};

  auto *icall_helpTy = FunctionType::get(Int32Ty, args, false);
  auto *helpTy = FunctionType::get(Int64Ty, args, false);
  auto *mem_helpTy = FunctionType::get(Int64Ty, args_mem, false);
  auto *log_helpTy = FunctionType::get(Int32Ty, log_args, false);
  auto *modify_helpTy = FunctionType::get(VoidTy, modify_args, false);

  Function *record_cmp = dyn_cast<Function>(M.getOrInsertFunction("__record_cmp", icall_helpTy).getCallee());
  Function *record_icall = dyn_cast<Function>(M.getOrInsertFunction("__record_icall", icall_helpTy).getCallee());
  Function *record_fptr_cmp = dyn_cast<Function>(M.getOrInsertFunction("__record_fptr_cmp", mem_helpTy).getCallee());
  Function *record_load = dyn_cast<Function>(M.getOrInsertFunction("__record_load", icall_helpTy).getCallee());
  Function *write_nginx_log = dyn_cast<Function>(M.getOrInsertFunction("__write_nginx_log", log_helpTy).getCallee());
 
  Function *modifyMemFunc = dyn_cast<Function>(M.getOrInsertFunction("__modify_mem_func",mem_helpTy).getCallee());

  if (mkdir("log", 0) == 0)
    chmod("log", 0777);

  line_log = fopen(LINE_LOG_FILE,"w+");
  fptr_cmp_log = fopen(FPTR_CMP_LOG_FILE,"w+");
  
    
  for (auto &F : M) {
    jump_collect = 0;
    errs() <<"Handling:" << F.getName() << "\n";

    if (F.getName().startswith("getAccessLogFd") || F.getName().startswith("apache_write_fd_afl") || F.getName().startswith("ngx_write_fd_afl") ) {
      errs() <<"Found:" << F.getName() << "\n";
      Module *write_module = F.getParent();
      LLVMContext &write_context = write_module->getContext();
     
      for (auto &BB : F) {
        if (&BB == &F.getEntryBlock()) {  
          // errs() <<"Found:entry" << "\n"; 
          IRBuilder<> Builder(&BB.front());  
          
          Value *FdArg = F.getArg(0); // get first argument fd
      
          Builder.CreateCall(write_nginx_log, {FdArg});
          break;
        }
      }

    //   // verify
    //     for (auto &BB : F) { 
        
    //       errs() << BB.getName() << "\n";
        
    //       for (auto &I : BB) {
      
    //         I.print(errs());
    //         errs()<< "\n";
    //   }
    // }

    }


    for (auto bbIter = F.begin(); bbIter != F.end();) {
      BasicBlock &BB = *bbIter;
      ++bbIter;
      //errs() <<"3" << "\n";
      /*Identify indirect call*/
      for (auto instIter = BB.begin(); instIter != BB.end();) {
        
        Instruction &I = *instIter;
        ++instIter;
        //I.print(errs());
        //errs()<< "\n";
        //errs() <<"4" << "\n";
        if (isa<ICmpInst>(&I)) {

            ICmpInst * ICMP = cast<ICmpInst>(&I);
            Value *firstValue = ICMP->getOperand(0);
            Value *secondValue = ICMP->getOperand(1);
            Type * firstType = firstValue->getType();

            // errs() << "First Operand: " << *firstValue << "\n";
            // errs() << "Second Operand: " << *secondValue << "\n";
            // errs() << "First Operand Type: " << *firstType << "\n";

            if (isFuncPtrTy(firstType) ||
                isCastedFromFuncPtr(firstValue) ||
                isCastedFromFuncPtr(secondValue)) {


                Value *fptr_cmp_address = NULL;

                // if (isa<ConstantPointerNull>(firstValue) && isa<Function>(secondValue)) {
                //   fptr_cmp_address = secondValue;
                // }

                // if (isa<Function>(firstValue) && isa<ConstantPointerNull>(secondValue)) {
                //   fptr_cmp_address = firstValue;
                // }

                if (isa<ConstantPointerNull>(firstValue) ||
                      isa<ConstantPointerNull>(secondValue)){ 
                    counter_null++;
                    errs() << "counter_null:\n";

                    if (isa<ConstantPointerNull>(firstValue)){
                      fptr_cmp_address = secondValue;
                    }
                    else{
                      fptr_cmp_address = firstValue;
                    }

                }

                if (isa<Function>(firstValue) ||
                      isa<Function>(secondValue)){
                  counter_FUNC++;
                  errs() << "counter_FUNC:\n";

                  if (isa<Function>(firstValue)){
                    fptr_cmp_address = secondValue;
                  }
                  else{
                    fptr_cmp_address = firstValue;
                  }    

                }

                if (fptr_cmp_address != NULL) {
                      IRBuilder<> builder(ICMP);

                    //printDebugInfo(*ICMP);
                    errs() <<"ready to log into fptr_cmp_log"<<"\n";
                    const DILocation *DIB = ICMP->getDebugLoc();
                    std::string debug_info;
                    if (DIB != nullptr) {
                        debug_info = DIB->getFilename().str() + ":" + std::to_string(DIB->getLine())+"\n";
                    } else {
                      debug_info = "no debug info\n";
                    }

                    std::string id_debug_pair = std::to_string(counter) + " " + debug_info;
                    errs() << "fptr_cmp_log write:" << id_debug_pair;
                    size_t str_length = strlen(id_debug_pair.c_str());

                    size_t written = fwrite(id_debug_pair.c_str(), 1, str_length, fptr_cmp_log);
                    if (written != str_length)
                      perror("failed to write to fptr_cmp_log");
                    
                    Value *fptr_address = fptr_cmp_address;
                    auto *fptr_cmp_id_ = builder.getInt64(counter);
                    std::vector<Value *> record_fptr_args = {fptr_address, fptr_cmp_id_};
                    builder.CreateCall(record_cmp,record_fptr_args);
                    
                    // when recording, need to locate which value you need to modify
                    // some of the null pointer check are initialization, not real
            
                    if (auto *loadInst = dyn_cast<LoadInst>(fptr_cmp_address)) {
                    // errs() << "Found fptr loadInst:" << *loadInst <<"\n";
                            if (loadInst->getDebugLoc()) {
                            DebugLoc debugLoc = loadInst->getDebugLoc();
                            unsigned line = debugLoc.getLine();
                            unsigned col = debugLoc.getCol();
                            StringRef filename = debugLoc->getScope()->getFilename();

                            errs() << "Location: " << filename << ":" << line << ":" << col << "\n\n\n\n";
                        } else {
                            errs() << "No debug information available\n";
                        }
                    IRBuilder<> builder(loadInst); // Insert before the load instruction
                
                    Value *load_address = loadInst->getPointerOperand();
                    
                    /* pass store id (currently it is the same with icall id)*/
                    auto *fptr_cmp_id = builder.getInt64(counter++);

                    std::vector<Value *> record_fptr_cmp_args = {load_address,fptr_cmp_id};

                    /* Insert a call to modify_memory (ptrToModify) [before load operation] */
                    Value *flipped = builder.CreateCall(record_fptr_cmp, record_fptr_cmp_args);

                    /* Update bitmap to represent we already perform the flipping*/

                    
                    LoadInst *MapPtr_ = builder.CreateLoad(AFLMapPtr);
                    MapPtr_->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

                    Value *FlipPtrIdx = 
                        builder.CreateGEP(MapPtr_, ConstantInt::get(Int32Ty, MAP_SIZE)); // increase share memory by 1
                    
                    // LoadInst *Flip_value = builder.CreateLoad(FlipPtrIdx);
                    // Flip_value->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                    builder.CreateStore(flipped, FlipPtrIdx)
                        ->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                      
                    }
                    else
                      errs() << "LoadInst Not Found\n";


              // std::vector<Value *> record_fptr_cmp_args = {fptr_cmp_address, fptr_cmp_id};
              // builder.CreateCall(record_fptr_cmp, record_fptr_cmp_args); 

                }
    
            
            }
        }

        //if (jump_collect) break;
        if (CallInst *CI = dyn_cast<CallInst>(&I)) { // instruction is a call instruction
          Function * calledF = dyn_cast<Function>(CI->getCalledOperand()->stripPointerCasts());   // exclude cast operations
          //Function * calledF = CI->getCalledFunction();
          if (calledF==nullptr) { 
            IRBuilder<> builder(CI);

            /* Debug Code */
            //I.print(errs());
              std::string InstrStr;
              llvm::raw_string_ostream OS(InstrStr);
              I.print(OS);

              if (StringRef(InstrStr).contains("} asm ") or StringRef(InstrStr).contains("i8 asm ") or StringRef(InstrStr).contains("* asm ") or StringRef(InstrStr).contains("void asm ") or StringRef(InstrStr).contains(" asm ")) {
                    // Your code when "asm" is found in the instruction
                    // Do something here
                    errs() << "Found asm in the instruction\n";
                    continue;
                }
              

            // summary dbg info
            const DILocation *DIB = CI->getDebugLoc();
            std::string debug_info;
            if (DIB != nullptr) {
              debug_info = DIB->getFilename().str() + ":" + std::to_string(DIB->getLine())+"\n";
            } else {
              debug_info = "no debug info\n";
            }
            
            /* Debug Code */
            //errs()<< debug_info << "\n";
            

            std::string id_debug_pair = std::to_string(icall_id) + " " + debug_info;
            size_t str_length = strlen(id_debug_pair.c_str());
            //mkdir("log",0755); 
            size_t written = fwrite(id_debug_pair.c_str(), 1, str_length, line_log);
            if (written != str_length)
              perror("failed to write to line_log");
            
            Value *call_address = CI->getCalledOperand(); //Return the pointer to function that is being called
            auto *icall_id_ = builder.getInt64(icall_id++);
            
            std::vector<Value *> record_icall_args = {call_address, icall_id_}; 
            builder.CreateCall(record_icall,record_icall_args);

            /*temporary disable flip_icall_target*/

            // // related flip code
            // std::vector<Value *> flip_icall_args = {call_address, icall_id_};
            // Value *target_function_value = builder.CreateCall(flip_icall,flip_icall_args); // flip target address
            // // do some address cast and pointer cast
            // Value *genericPtr = builder.CreateIntToPtr(target_function_value, Type::getInt8PtrTy(C));

            // Type *targetFuncPtrType = CI->getCalledOperand()->getType();

            // Value *castedFunctionPtr = builder.CreateBitCast(genericPtr, targetFuncPtrType);

            // // if (target_function_value->getType()->getPointerAddressSpace() == 64) {
                
            // //     FunctionType *funcType = CI->getFunctionType();
                
            // //     // cast target_function_value from addrspace(64) to addrspace(0)
            // //     target_function_value = builder.CreateAddrSpaceCast(target_function_value, funcType->getPointerTo(0));
            // // }
            // CI->setCalledOperand(castedFunctionPtr);

            // //errs() << " 3\n";
            
          }
        
        
          /*ZC: Add load instruction tracing*/
          if (calledF==nullptr) {
              std::string InstrStr;
              llvm::raw_string_ostream OS(InstrStr);
              I.print(OS);

              if (StringRef(InstrStr).contains("} asm ") or StringRef(InstrStr).contains("i8 asm ") or StringRef(InstrStr).contains("* asm ") or StringRef(InstrStr).contains("void asm ") or StringRef(InstrStr).contains(" asm ")) {
                    // Your code when "asm" is found in the instruction
                    // Do something here
                    errs() << "Found asm in the instruction\n";
                    continue;
              }
              // errs() << "Found icall\n";
              // Check if the called value is loaded from a pointer
              Value *calledValue = CI->getCalledOperand();
              // errs() << "Called Operand Value: " << *calledValue << "\n";
              if (auto *loadInst = dyn_cast<LoadInst>(calledValue)) {
                  // errs() << "Found loadInst\n";
                  IRBuilder<> builder(loadInst); // Insert before the load instruction
              
                  // //Cast the pointer operand to i8** to match modify_memory(void**)
                  // Value *ptrToModify = builder.CreateBitCast(
                  //   loadInst->getPointerOperand(),
                  //   PointerType::get(Type::getInt8PtrTy(C),0)
                  // );

                  Value *load_address = loadInst->getPointerOperand();
                  
                  /* pass store id (currently it is the same with icall id)*/
                  auto *icall_id_ = builder.getInt64(icall_id-1);

                  std::vector<Value *> modify_mem_arg = {load_address,icall_id_};

                  /* Insert a call to modify_memory (ptrToModify) [before load operation] */
                  Value *flipped = builder.CreateCall(modifyMemFunc, modify_mem_arg);

                  /* Update bitmap to represent we already perform the flipping*/
      
                  
                  LoadInst *MapPtr_ = builder.CreateLoad(AFLMapPtr);
                  MapPtr_->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

                  Value *FlipPtrIdx = 
                      builder.CreateGEP(MapPtr_, ConstantInt::get(Int32Ty, MAP_SIZE)); // increase share memory by 1
                  
                  // LoadInst *Flip_value = builder.CreateLoad(FlipPtrIdx);
                  // Flip_value->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                  builder.CreateStore(flipped, FlipPtrIdx)
                      ->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));


                  /* Insert a call to record load value [after load operation]*/
                  IRBuilder<> after_builder(loadInst->getNextNode());

                  Value *loadedValue = loadInst;
                  // errs() << "loadedValue:" << *loadedValue << "\n";
                  std::vector<Value *> record_load_args = {loadedValue, icall_id_};
                  after_builder.CreateCall(record_load,record_load_args);

              
              }
              else
                errs() << "LoadInst Not Found\n";
          }
        
        }
      }

      BasicBlock::iterator IP = BB.getFirstInsertionPt();
      IRBuilder<> IRB(&(*IP));

      if (AFL_R(100) >= inst_ratio) continue;

      /* Make up cur_loc */

      unsigned int cur_loc = AFL_R(MAP_SIZE);

      ConstantInt *CurLoc = ConstantInt::get(Int32Ty, cur_loc);
      
      
      /* Load prev_loc */

      LoadInst *PrevLoc = IRB.CreateLoad(AFLPrevLoc);
      PrevLoc->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      Value *PrevLocCasted = IRB.CreateZExt(PrevLoc, IRB.getInt32Ty());

      /* Load SHM pointer */

      LoadInst *MapPtr = IRB.CreateLoad(AFLMapPtr);
      MapPtr->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      Value *MapPtrIdx =
          IRB.CreateGEP(MapPtr, IRB.CreateXor(PrevLocCasted, CurLoc));

      /* Update bitmap */

      LoadInst *Counter = IRB.CreateLoad(MapPtrIdx);
      Counter->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      Value *Incr = IRB.CreateAdd(Counter, ConstantInt::get(Int8Ty, 1));
      IRB.CreateStore(Incr, MapPtrIdx)
          ->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
 
      /* Set prev_loc to cur_loc >> 1 */

      StoreInst *Store =
          IRB.CreateStore(ConstantInt::get(Int32Ty, cur_loc >> 1), AFLPrevLoc);
      Store->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));


      inst_blocks++;
    }
}

  /* Debug IR Code */

  // for (auto &F : M){
  //     errs() << F.getName() << "\n";
      
  //     for (auto &BB : F) { 
  //       errs() << BB.getName() << "\n";
        
  //       for (auto &I : BB) {
      
  //         I.print(errs());
  //         errs()<< "\n";
  //     }
  //   }
  // }



  fclose(line_log);
  fclose(fptr_cmp_log);
  /* Say something nice. */
  
  if (!be_quiet) {

    if (!inst_blocks) WARNF("No instrumentation targets found.");
    else OKF("Instrumented %u locations (%s mode, ratio %u%%).",
             inst_blocks, getenv("AFL_HARDEN") ? "hardened" :
             ((getenv("AFL_USE_ASAN") || getenv("AFL_USE_MSAN")) ?
              "ASAN/MSAN" : "non-hardened"), inst_ratio);


  }

  return true;

}

static void registerAFLPass(const PassManagerBuilder &,
                            legacy::PassManagerBase &PM) {

  PM.add(new AFLCoverage());

}


static RegisterStandardPasses RegisterAFLPass(
    PassManagerBuilder::EP_ModuleOptimizerEarly, registerAFLPass);

static RegisterStandardPasses RegisterAFLPass0(
    PassManagerBuilder::EP_EnabledOnOptLevel0, registerAFLPass);
