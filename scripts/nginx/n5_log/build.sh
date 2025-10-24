#!/bin/bash 

# Script for Nginx logging N5

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O1" CXXFLAGS="-g -O1"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --prefix="$(pwd)/bin" --with-select_module --with-debug  --with-ld-opt="-Wl,-rpath,/usr/local/lib"  --add-module=./ModSecurity-nginx
make -j$(nproc) && make install

# -------------------- build flip binaries -----------------------------------

cd bin/sbin/ 
extract-bc nginx
export EXTRA_LDFLAGS="-lz -lc -ldl -lpthread -lcrypt -lpcre2-8 -lxml2 -llua5.1 -lpcre -lstdc++ -lgcc_s -licuuc -llzma -licudata -L/usr/local/modsecurity/lib/ -lmodsecurity"
cp $SACK/scripts/nginx/n5_log/vsack.conf ./log/
cp $SACK/scripts/nginx/n5_log/ban_line.list ./log/

$SACK/viper/BranchForcer/afl-clang-fast-flip nginx.bc -o nginx.fuzz -Wl,--export-dynamic -Wl,-rpath=/usr/local/modsecurity/lib/ $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/viper/tools/copy_tools.sh $SACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $SACK/viper/BranchForcer/afl-fuzz -c ./log/vsack.conf -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
