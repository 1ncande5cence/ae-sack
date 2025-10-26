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
#include <iostream>

#include <string.h>
#include "sys/stat.h"
#include <dirent.h>
#include <json/json.h>  //sudo apt-get install libjsoncpp-dev
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

#define LINE_LOG_FILE       "./log/line_log"
#define ADDRESS_LOG_FILE    "./log/address_log"

char AFLCoverage::ID = 0;

// Global variable to store log_func from config
std::string g_log_func_name = "";

// Global flag to enable/disable logging
// Set to false to disable all logFile logging (e.g., g_enable_logging = false;)
bool g_enable_logging = false;

// Global flag to indicate fake instrumentation (when branch matches ban_line.list)
bool g_fake_instrument = false;

// Global vector to store ban lines for fast lookup
std::vector<std::string> g_ban_lines;

// Macro for conditional logging
#define LOG_TO_FILE if (g_enable_logging) logFile

// Function to check if branch_debug_info matches any line in ban_line.list
bool checkBanLineMatch(const std::string& icall_debug_info) {
    // Check against stored ban lines (no file I/O)
    for (const auto& banLine : g_ban_lines) {
        if (icall_debug_info.find(banLine) != std::string::npos) {
            return true;
        }
    }
    return false;
}

// Function to parse JSON config and ban_line.list
void parseFromConfig() {
  // Find the first *.conf file in ./log directory
  std::string configPath = "./log/sack.conf";

  std::ifstream configFile(configPath);
  if (!configFile.is_open()) {
      fprintf(stderr, "Error: Could not open config file: %s\n", configPath.c_str());
      exit(1);
  }
 
  Json::Value root;
  Json::CharReaderBuilder builder;
  std::string errors;

  if (!Json::parseFromStream(builder, configFile, &root, &errors)) {
      fprintf(stderr, "Error: Failed to parse JSON config: %s\n", errors.c_str());
      exit(1);
  }

  if (root.isMember("log_func") && root["log_func"].isString()) {
      g_log_func_name = root["log_func"].asString();
  } else {
      fprintf(stderr, "Error: log_func field not found or not a string in config file: %s\n", configPath.c_str());
      exit(1);
  }

  // Parse ban_line.list file
  std::string banLinePath = "./log/ban_line.list";
  std::ifstream banLineFile(banLinePath);
  
  if (banLineFile.is_open()) {
      std::string line;
      while (std::getline(banLineFile, line)) {
          // Remove trailing whitespace and newlines
          line.erase(line.find_last_not_of(" \t\r\n") + 1);
          
          // Skip empty lines
          if (!line.empty()) {
              g_ban_lines.push_back(line);
          }
      }
      banLineFile.close();
      
      errs() << "Loaded ban lines:\n";
      for (const auto &line : g_ban_lines) {
        errs() << "  [ban] " << line << "\n";
      }
      
  }

  // If ban_line.list doesn't exist, output a warning and continue with empty ban list
  else {
      errs() << "Warning: ban_line.list not found at " << banLinePath << ", continuing with empty ban list.\n";
  }
  
}


bool AFLCoverage::runOnModule(Module &M) {

  LLVMContext &C = M.getContext();
  errs() << M.getName() << "\n";
  errs() << M.getSourceFileName() << "\n";
  IntegerType *Int8Ty  = IntegerType::getInt8Ty(C);
  IntegerType *Int32Ty = IntegerType::getInt32Ty(C);
  IntegerType *Int64Ty = IntegerType::getInt64Ty(C);
  PointerType *Int8PtrTy = Type::getInt8PtrTy(C);

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
  int inst_blocks = 0;
  /* Prepare for the function insertion*/

  uint64_t icall_id = 0;
  uint64_t jump_collect = 0;
  std::vector<Type *> args = {Int64Ty, Int64Ty};
  std::vector<Type *> args_mem = {Int64Ty, Int64Ty};
  std::vector<Type *> log_args = {Int32Ty};
  std::vector<Type *> modify_args = {Int8PtrTy};

  auto *icall_helpTy = FunctionType::get(Int32Ty, args, false);
  auto *mem_helpTy = FunctionType::get(Int64Ty, args_mem, false);
  auto *log_helpTy = FunctionType::get(Int32Ty, log_args, false);

  Function *record_icall = dyn_cast<Function>(M.getOrInsertFunction("__record_icall", icall_helpTy).getCallee());
  Function *write_nginx_log = dyn_cast<Function>(M.getOrInsertFunction("__write_nginx_log", log_helpTy).getCallee());
  Function *modifyMemFunc = dyn_cast<Function>(M.getOrInsertFunction("__modify_mem_func",mem_helpTy).getCallee());

  if (mkdir("log", 0) == 0)
    chmod("log", 0777);

  line_log = fopen(LINE_LOG_FILE,"w+");

  // Parse log_func from config file
  parseFromConfig();
    
  for (auto &F : M) {
    jump_collect = 0;
    //errs() <<"Handling:" << F.getName() << "\n";


    if (F.getName().startswith("getAccessLogFd") || F.getName().startswith("apache_write_fd_afl") || F.getName().startswith(g_log_func_name) ) {
      //errs() <<"Found:" << F.getName() << "\n";
     
      for (auto &BB : F) {
        if (&BB == &F.getEntryBlock()) {  
          // errs() <<"Found:entry" << "\n"; 
          IRBuilder<> Builder(&BB.front());  
          
          Value *FdArg = F.getArg(0); // get first argument fd
      
          Builder.CreateCall(write_nginx_log, {FdArg});
          break;
        }
      }
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

        //if (jump_collect) break;
        if (CallInst *CI = dyn_cast<CallInst>(&I)) { // instruction is a call instruction
          Function * calledF = dyn_cast<Function>(CI->getCalledOperand()->stripPointerCasts());   // exclude cast operations
          //Function * calledF = CI->getCalledFunction();
          if (calledF==nullptr) { 
            g_fake_instrument = false; // re-initialize
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
            std::string icall_debug_info;
            if (DIB != nullptr) {
              icall_debug_info = DIB->getFilename().str() + ":" + std::to_string(DIB->getLine())+"\n";
            } else {
              icall_debug_info = "no_debug_info\n";
            }
            
            /* Debug Code */
            //errs()<< icall_debug_info << "\n";
            
            // Check if this branch matches any line in ban_line.list
            std::string icall_compare_debug_info = icall_debug_info;
            if (!icall_compare_debug_info.empty() && icall_compare_debug_info.back() == '\n') {
                icall_compare_debug_info.erase(icall_compare_debug_info.find_last_not_of(" \t\r\n") + 1);
            }

            if (checkBanLineMatch(icall_compare_debug_info)) {
                errs() <<"Found ban line match ban_line.list:" << icall_compare_debug_info << "\n";
                g_fake_instrument = true;  // if match, we don't instrument this branch for some important function, but log all the things
            }

            std::string id_debug_pair = std::to_string(icall_id) + " " + icall_debug_info;
            size_t str_length = strlen(id_debug_pair.c_str());
            //mkdir("log",0755); 
            size_t written = fwrite(id_debug_pair.c_str(), 1, str_length, line_log);
            if (written != str_length)
              perror("failed to write to line_log");
            
            Value *call_address = CI->getCalledOperand(); //Return the pointer to function that is being called
            auto *icall_id_ = builder.getInt64(icall_id++);
            
            std::vector<Value *> record_icall_args = {call_address, icall_id_}; 
            builder.CreateCall(record_icall,record_icall_args);

            
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
                  Value *flipped = builder.getInt64(0);
                  if (!g_fake_instrument) {  // if fake instrument, we don't instrument to modify memory
                    flipped =builder.CreateCall(modifyMemFunc, modify_mem_arg);
                  }
                  else { errs() <<"fake instrument[1/1],not instrument to modify memory"<< "\n";}


                  /* Update bitmap to represent we already perform the flipping*/
      
                  if (!g_fake_instrument) {
                  LoadInst *MapPtr_ = builder.CreateLoad(AFLMapPtr);
                  MapPtr_->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

                  Value *FlipPtrIdx = 
                      builder.CreateGEP(MapPtr_, ConstantInt::get(Int32Ty, MAP_SIZE)); // increase share memory by 1
                  
                  // LoadInst *Flip_value = builder.CreateLoad(FlipPtrIdx);
                  // Flip_value->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                  
                  builder.CreateStore(flipped, FlipPtrIdx)
                      ->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
                  }
              }
              else {
                errs() <<"Handling:" << F.getName() << "\n";
                errs() << "LoadInst Not Found\n";
              }
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
