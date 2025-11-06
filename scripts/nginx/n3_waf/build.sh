#!/bin/bash
set -euo pipefail 

# Script for Nginx waf N3

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --prefix="$(pwd)/bin" --with-select_module --with-debug  --with-ld-opt="-Wl,-rpath,/usr/local/lib"  --add-module=./ModSecurity-nginx
make -j$(nproc) && make install

# -------------------- build flip binaries -----------------------------------

cd bin/sbin/ 
extract-bc nginx
export EXTRA_LDFLAGS="-lz -lc -ldl -lpthread -lcrypt -lpcre2-8 -lxml2 -llua5.1 -lpcre -lstdc++ -lgcc_s -licuuc -llzma -licudata -L/usr/local/modsecurity/lib/ -lmodsecurity"
mkdir -p ./log
cp $SACK/scripts/nginx/n3_waf/sack.conf ./log/
cp $SACK/scripts/nginx/n3_waf/ban_line.list ./log/

#$SACK/AFL/afl-clang-fast-indirect-flip nginx.bc -o nginx.fuzz -Wl,--export-dynamic -Wl,-rpath=/usr/local/modsecurity/lib/ $EXTRA_LDFLAGS >compile.log 2>&1
$SACK/AFL/afl-clang-fast-indirect-flip nginx.bc -o nginx.fuzz -Wl,--export-dynamic -Wl,-rpath=/usr/local/modsecurity/lib/ $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/nginx/n3_waf/copy_tools.sh $SACK .
objdump -d ./nginx.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh------------------------------------


# -------------------- do substitution --------------------------------------
# in ./bin/sbin/ folder

# terminal 1 
# python3 send_request_waf.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz  -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000+ -- ./nginx.fuzz


# -------------------- result analysis --------------------------------------

# use corresponding analyze.sh at the ./bin/sbin/ folder

# the result is in the result.*/ folder report_satisfied.txt
