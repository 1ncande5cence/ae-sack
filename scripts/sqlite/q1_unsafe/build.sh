#!/bin/bash 

# Script for SQLite3 unsafe command Q1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y tcl-dev
./configure 
make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir bin_viper_safemode
cp sqlite3 ./bin_viper_safemode
cd ./bin_viper_safemode
extract-bc sqlite3
export EXTRA_LDFLAGS="-lpthread -lz -lm -ldl -lreadline"
mkdir -p ./log
rm -rf oracle
mkdir oracle
cp $SACK/scripts/sqlite/q1_unsafe/vsack.conf ./log/
cp $SACK/scripts/sqlite/q1_unsafe/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip sqlite3.bc -o sqlite3.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/tools/copy_tools.sh $SACK .
objdump -d ./sqlite3.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $SACK/AFL/afl-fuzz -c ./log/vsack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sqlite3.fuzz -safe


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
