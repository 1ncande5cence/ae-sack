---- design ----

design is separated into different component

1. llvm_mode  ( perform the instrumentation )
在llvm_mode_indirect的基础上进行开发

1) 读一个文本文件，包含了ground truth target
e.g.
icall A:
    function_a
    function_b
    function_c
icall B:
    function_a
    function_e

首先先整理成一个数据结构

给每一个分配unique id， 比如说第一个 （icall A 对应 function_a）叫作 1_1,
followed by 1_2, 1_3, 1_4

2) 找到每一个icall的位置, call一个函数，这个函数根据id的值，修改call的
icall targets (用和viper一样的模式)

**有几个目标target，就Create几个Call**

关键变量：
std::to_string(icall_id)


if (id != flip_icall_id) continue/return 

if so, extract target function, and replace it 

2. afl-fuzz.c ( perform the flip )

(design later)

------

Task 01:
在插桩的时候，通过什么定位函数是什么？ 从而完成修改？   （从函数名字）

(possible modification method)  最好直接修改CalleePtr

void replaceIndirectCall(Module &M) {
    // 假设目标函数是 "target_func"
    Function *targetFunc = M.getFunction("target_func");

    // 遍历模块中的所有函数
    for (Function &F : M) {
        for (BasicBlock &BB : F) {
            for (Instruction &I : BB) {
                // 检查是否是一个调用指令 (CallInst)
                if (CallInst *callInst = dyn_cast<CallInst>(&I)) {
                    // 检查是否是间接调用
                    if (!callInst->getCalledFunction()) {
                        // 获取原来的函数指针
                        Value *calledValue = callInst->getCalledOperand();

                        // 打印原来的间接调用
                        calledValue->dump();

                        // 修改为调用目标函数
                        IRBuilder<> builder(callInst);
                        std::vector<Value*> args(callInst->arg_begin(), callInst->arg_end());

                        // 创建新的直接调用目标函数的指令
                        CallInst *newCall = builder.CreateCall(targetFunc, args);

                        // 替换原来的调用指令
                        callInst->replaceAllUsesWith(newCall);
                        callInst->eraseFromParent();
                    }
                }
            }
        }
    }
}

修改完之后需要改回来吗？

修改的方式还要再细化：

 rc = ph[r->phase_handler].checker(r, &ph[r->phase_handler]);

其实修改的是 ph[r->phase_handler].checker = ngx_http_core_post_rewrite_phase 

看一下ir级别的代码

%27 = load %struct.ngx_http_phase_handler_s.1452*, %struct.ngx_http_phase_handler_s.1452** %4, align 8, !dbg !155393
%31 = getelementptr inbounds %struct.ngx_http_phase_handler_s.1452, %struct.ngx_http_phase_handler_s.1452* %27, i64 %30, !dbg !155393
%32 = getelementptr inbounds %struct.ngx_http_phase_handler_s.1452, %struct.ngx_http_phase_handler_s.1452* %31, i32 0, i32 0, !dbg !155397
%33 = load i64 (%struct.ngx_http_request_s.1446*, %struct.ngx_http_phase_handler_s.1452*)*, i64 (%struct.ngx_http_request_s.1446*, %struct.ngx_http_phase_handler_s.1452*)** %32, align 8, !dbg !155397
%40 = call i64 %33(%struct.ngx_http_request_s.1446* %34, %struct.ngx_http_phase_handler_s.1452* %39), !dbg !155393

如果可以做到修改%33  这是一个粒度的问题，先实现一个最简单的


----
1. 格式化 收集到的icall和icall target的表格， 方便读取

icall id:target_num
[1]:ngx_core_module_init_conf
[2]:ngx_regex_init_conf
[3]:ngx_event_init_conf

e.g., 

(25:  src/core/ngx_cycle.c:239)

25:3
[1]:ngx_core_module_init_conf
[2]:ngx_regex_init_conf
[3]:ngx_event_init_conf

有两种cvs结构, 
1.平铺结构, 适合处理target数量不定的情况，容易动态添加和删除目标
icall_id,target_num,target_id,target_name
25,3,1,ngx_core_module_init_conf
25,3,2,ngx_regex_init_conf
25,3,3,ngx_event_init_conf

2.扁平化结构， 同一行存储多个target, 适合target数量固定时使用
icall_id,target_num,target_1,target_2,target_3
25,3,ngx_core_module_init_conf,ngx_regex_init_conf,ngx_event_init_conf

先采取平铺结构

如果 icall number is 1, then we do not filp 