#!/bin/bash 

# ATTENTION:
# use O1
# SACK dir changes

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --prefix="$(pwd)/bin" --with-select_module --with-debug --with-http_ssl_module 
make -j$(nproc) && make install

# -------------------- build flip binaries -----------------------------------

cd bin/sbin/ 
extract-bc nginx
export EXTRA_LDFLAGS="-lz -lc -ldl -lpthread -lpcre2-8 -lcrypto -lcrypt -lssl"
$SACK/AFL/afl-clang-fast-indirect-flip nginx.bc -o nginx.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/viper/tools/copy_tools.sh $SACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# export AFL_NO_AFFINITY=1
# $SACK/AFL/afl-fuzz -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
