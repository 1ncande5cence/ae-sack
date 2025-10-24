#!/bin/bash 

# Script for Sudo extra approval  U2

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O1" CXXFLAGS="-g -O1"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --enable-static-sudoers --enable-python --disable-shared-libutil --enable-openssl=no LDFLAGS="-static"

make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir -p src/bin
cp src/sudo src/bin/
cd src/bin
extract-bc sudo
export EXTRA_LDFLAGS="-lutil -lsudo_util -lcrypt -lpthread -lc -ldl -lz"
export LD_LIBRARY_PATH=/usr/local/libexec/sudo:$LD_LIBRARY_PATH

mkdir -p ./log
cp $SACK/scripts/sudo/u1_log/vsack.conf ./log/
cp $SACK/scripts/sudo/u1_log/ban_line.list ./log/

$SACK/viper/BranchForcer/afl-clang-fast-flip sudo.bc -o sudo.fuzz -L/usr/local/libexec/sudo/ -Wl,-rpath, /usr/local/libexec/sudo/ $EXTRA_LDFLAGS

chmod 4755 ./sudo.fuzz

# -------------------- prepare tools and environments --------------------------

bash $SACK/viper/tools/copy_tools.sh $SACK .
objdump -d ./sudo.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# cd src/bin
# export AFL_NO_AFFINITY=1
# $SACK/viper/BranchForcer/afl-fuzz -c ./log/vsack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sudo.fuzz ls /root

# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
