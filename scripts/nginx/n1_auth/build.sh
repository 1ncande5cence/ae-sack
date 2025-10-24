#!/bin/bash 

# Script for Nginx authentication N1

# Some settings
export VSACK=/vsack.new/vsack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O1" CXXFLAGS="-g -O1"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --prefix="$(pwd)/bin" --with-select_module --with-debug
make -j$(nproc) && make install

# -------------------- build flip binaries -----------------------------------

cd bin/sbin/ 
extract-bc nginx
export EXTRA_LDFLAGS="-lz -lc -ldl -lpthread -lpcre2-8 -lcrypt"
mkdir -p ./log
cp $VSACK/scripts/nginx/n1_auth/vsack.conf ./log/
cp $VSACK/scripts/nginx/n1_auth/ban_line.list ./log/
$VSACK/viper/BranchForcer/afl-clang-fast-flip nginx.bc -o nginx.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $VSACK/viper/tools/copy_tools.sh $VSACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $VSACK/viper/BranchForcer/afl-fuzz -c ./log/vsack.conf -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz


# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
