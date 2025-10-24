#!/bin/bash 

# Script for SQLite3 readonly Q2

# Some settings
export VSACK=/vsack.new/vsack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O1" CXXFLAGS="-g -O1"
apt install -y tcl-dev
./configure 
make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir bin_viper_readonly
cp sqlite3 ./bin_viper_readonly
cd ./bin_viper_readonly
extract-bc sqlite3
export EXTRA_LDFLAGS="-lpthread -lz -lm -ldl -lreadline"
mkdir -p ./log
rm -rf oracle
mkdir oracle
cp $VSACK/scripts/sqlite/q1_unsafe/vsack.conf ./log/
cp $VSACK/scripts/sqlite/q1_unsafe/ban_line.list ./log/
$VSACK/viper/BranchForcer/afl-clang-fast-flip sqlite3.bc -o sqlite3.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $VSACK/viper/tools/copy_tools.sh $VSACK .
objdump -d ./sqlite3.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $VSACK/viper/BranchForcer/afl-fuzz -c ./log/vsack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sqlite3.fuzz -readonly my_database_noage.db


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
