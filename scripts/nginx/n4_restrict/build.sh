#!/bin/bash
set -euo pipefail 

# Script for Nginx Restrict Method N4

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --prefix="$(pwd)/bin" --with-select_module --with-debug
make -j$(nproc) && make install

# -------------------- build flip binaries -----------------------------------

cd bin/sbin/ 
extract-bc nginx
export EXTRA_LDFLAGS="-lz -lc -ldl -lpthread -lpcre2-8 -lcrypt"
mkdir -p ./log
cp $SACK/scripts/nginx/n4_restrict/sack.conf ./log/
cp $SACK/scripts/nginx/n4_restrict/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip nginx.bc -o nginx.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/nginx/n4_restrict/copy_tools.sh $SACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh  ------------------------------------


# -------------------- do substitution --------------------------------------
# in ./bin/sbin/ folder

# terminal 1 
# python3 send_request_disable.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz

# when substitution finish, stop the python script

# -------------------- result analysis --------------------------------------

# use corresponding analyze.sh at the /target/nginx/nginx-disable-method/bin/sbin folder

# the result is in the result.*/ folder report_satisfied.txt