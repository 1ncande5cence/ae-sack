#!/bin/bash
set -euo pipefail 

# Script for Nginx SSL encryption N6

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
mkdir -p ./log
cp $SACK/scripts/nginx/n6_ssl/sack.conf ./log/
cp $SACK/scripts/nginx/n6_ssl/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip nginx.bc -o nginx.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/nginx/n6_ssl/copy_tools.sh $SACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------



# -------------------- do substitution --------------------------------------
# in bin/sbin/ folder

# terminal 1 
# python3 send_request_https.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz

# terminal 3
# ngrep -W byline -d lo -t '' 'port 80 or port 443' >log/sniff_log

# -------------------- result analysis --------------------------------------

# analyze sniff_log to see any plaintext traffic with 200 status code