#!/bin/bash 

# Script for Proftpd limit P2

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-ctrls --with-modules=mod_ban
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

mkdir bin
cp proftpd bin/
cd bin
extract-bc proftpd
export EXTRA_LDFLAGS="-lcrypt -lc -ldl"
mkdir -p ./log
cp $SACK/scripts/proftpd/p2_limit/vsack.conf ./log/
cp $SACK/scripts/proftpd/p2_limit/ban_line.list ./log/
cp $SACK/scripts/proftpd/p2_limit/sack_analyze.py ./
cp $SACK/scripts/proftpd/p2_limit/proftpd.conf /tmp/
$SACK/AFL/afl-clang-fast-indirect-flip proftpd.bc -o proftpd.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/viper/tools/copy_tools.sh $SACK .
objdump -d ./proftpd.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------

# python3 ftpreq_limit_oracle1.py

# export AFL_NO_AFFINITY=1
# cd bin
# !!! before running, modify /tmp/proftpd.conf ban location  (-c require absolute path)
# $SACK/AFL/afl-fuzz -c ./log/vsack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /tmp/proftpd.conf -d 5 -X


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
