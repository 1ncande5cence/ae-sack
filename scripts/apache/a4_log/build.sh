#!/bin/bash
set -euo pipefail 

# Script for Apache logging A4

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-so --with-mpm=event --with-included-apr --with-ssl=/usr/local/openssl --disable-shared --enable-mods-static=reallyall
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

extract-bc httpd

mkdir -p ./log
cp $SACK/scripts/apache/a4_log/sack.conf ./log/
cp $SACK/scripts/apache/a4_log/ban_line.list ./log/
cp $SACK/scripts/apache/a4_log/httpd.conf /usr/local/apache2/conf/
cp $SACK/scripts/apache/a4_log/httpd.conf /usr/local/apache2/conf.bak/
$SACK/AFL/afl-clang-fast-indirect-flip httpd.bc -o httpd.fuzz -L/target/httpd-log/srclib/apr/.libs -L/usr/local/openssl/lib -Wl,-rpath,/target/httpd-log/srclib/apr/.libs -Wl,-rpath,/usr/local/openssl/lib -lapr-2 -lpcre2-8 -luuid -lrt -lcrypt -lpthread -ldl -lexpat -lssl -lcrypto -lnghttp2 -lxml2 -llua5.1 -licuuc -llzma -licudata -lz -Wl,--export-dynamic

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/apache/a4_log/copy_tools.sh $SACK .
objdump -d ./httpd.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen_apache.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------

# -------------------- first dry-run to collect target ------------------------------------

# ./httpd.fuzz -X -d /usr/local/apache2
# curl localhost
# mv log/address_log log/subgt-extract/success_log

# -------------------- do branch flipping --------------------------------------
# in current folder

# terminal 1
# python3 send_request.logging.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -d -c ./log/sack.conf -m none -i ./input/ -o ./output/ -t 1000+ -- ./httpd.fuzz -X -d /usr/local/apache2

# -------------------- result analysis --------------------------------------

# use analyze.sh at the bin/sbin/ folder

# the result is in the result.*/ folder report_unique.txt
