#!/bin/bash
set -euo pipefail 

# Script for Sudo logging U1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --disable-shared --disable-shared-libutil --enable-static-sudoers

make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir -p src/bin
cp src/sudo src/bin/
cd src/bin
extract-bc sudo
export EXTRA_LDFLAGS="-lutil -lsudo_util -lcrypt -lpthread -lc -ldl -lz -lssl -lcrypto"
export LD_LIBRARY_PATH=/usr/local/libexec/sudo:$LD_LIBRARY_PATH

mkdir -p ./log
cp $SACK/scripts/sudo/u1_log/sack.conf ./log/
cp $SACK/scripts/sudo/u1_log/ban_line.list ./log/
cp $SACK/scripts/sudo/u1_log/check_missing.py ./

$SACK/AFL/afl-clang-fast-indirect-flip sudo.bc -o sudo.fuzz -L/usr/local/libexec/sudo/ -Wl,-rpath, /usr/local/libexec/sudo/ $EXTRA_LDFLAGS

chmod 4755 ./sudo.fuzz

# -------------------- prepare tools and environments --------------------------

bash $SACK/tools/copy_tools.sh $SACK .
objdump -d ./sudo.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# cd src/bin
# export AFL_NO_AFFINITY=1
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sudo.fuzz ls /root

# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
