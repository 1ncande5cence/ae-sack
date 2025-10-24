#!/bin/bash 

# Script for SQLite3 unsafe command Q1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC="wllvm" CXX="wllvm++" BUILD_CC="wllvm" BUILD_CXX="wllvm++" LLVM_COMPILER=clang AR=llvm-ar NM=llvm-nm BUILD_AR=llvm-ar BUILD_NM=llvm-nm 
apt install -y bison cdbs curl flex g++ git python vim pkg-config ninja-build
# gn gen x64.debug
cp $SACK/scripts/v8/v1_unsafe/args.gn x64.debug
ninja -C x64.debug "v8_monolith" "d8"

# -------------------- build flip binaries -----------------------------------

cd x64.debug
cp ./obj/libv8_monolith.a .
extract-bc d8

mkdir -p ./log
rm -rf oracle
mkdir oracle
cp $SACK/scripts/v8/v1_unsafe/sack.conf ./log/
cp $SACK/scripts/v8/v1_unsafe/ban_line.list ./log/
mkdir input
cp $SACK/scripts/v8/v1_unsafe/os.system.js ./input/
$SACK/AFL/afl-clang-fast-indirect-flip d8.bc -o d8.fuzz -lpthread -lm -latomic -lstdc++ -lc -lgcc_s libv8_monolith.a

# -------------------- prepare tools and environments --------------------------

bash $SACK/tools/copy_tools.sh $SACK .
objdump -d ./d8.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m none -i ./input -o ./output/ -t 5000+ -- ./d8.fuzz @@


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
