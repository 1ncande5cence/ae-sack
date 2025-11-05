#!/bin/bash
set -euo pipefail 

# Script for Apache authentication A1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-so --with-mpm=event --with-included-apr --with-ssl=/usr/local/openssl --disable-shared --enable-mods-static=reallyall
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

extract-bc httpd

mkdir -p ./log
cp $SACK/scripts/apache/a1_auth/sack.conf ./log/
cp $SACK/scripts/apache/a1_auth/ban_line.list ./log/
cp $SACK/scripts/apache/a1_auth/httpd.conf /usr/local/apache2/conf/
cp $SACK/scripts/apache/a1_auth/httpd.conf /usr/local/apache2/conf.bak/
$SACK/AFL/afl-clang-fast-indirect-flip httpd.bc -o httpd.fuzz -L/target/httpd-auth/srclib/apr/.libs -L/usr/local/openssl/lib -Wl,-rpath,/target/httpd-auth/srclib/apr/.libshttpd/srclib/apr/.libs -Wl,-rpath,/usr/local/openssl/lib -lapr-2 -lpcre2-8 -luuid -lrt -lcrypt -lpthread -ldl -lexpat -lssl -lcrypto -lnghttp2 -lxml2 -llua5.1 -licuuc -llzma -licudata -lz -Wl,--export-dynamic

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/apache/a1_auth/copy_tools.sh $SACK .
objdump -d ./httpd.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------


# -------------------- first dry-run to collect target ------------------------------------

# ./httpd.fuzz -X -d /usr/local/apache2
# curl -u song:secret http://localhost/private/
# mv log/address_log log/subgt-extract/success_log


# -------------------- do substitution --------------------------------------
# in current folder


# terminal 1
# python3 send_request.auth.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -d -c ./log/sack.conf -m none -i ./input/ -o ./output/ -t 1000+ -- ./httpd.fuzz -X -d /usr/local/apache2

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# the result is in the result.*/ folder report_satisfied.txt