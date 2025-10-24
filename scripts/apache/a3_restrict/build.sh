#!/bin/bash 

# Script for Apache restrict method A3

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-so --with-mpm=event --with-included-apr --with-ssl=/usr/local/openssl --disable-shared --enable-mods-static=reallyall
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

extract-bc httpd

mkdir -p ./log
cp $SACK/scripts/apache/a3_restrict/sack.conf ./log/
cp $SACK/scripts/apache/a3_restrict/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip httpd.bc -o httpd.fuzz -L/song/apache-httpd/sack/httpd.o1/srclib/apr/.libs -L/usr/local/openssl/lib -Wl,-rpath,/song/apache-httpd/sack/httpd.o1/srclib/apr/.libs -Wl,-rpath,/usr/local/openssl/lib -lapr-2 -lpcre2-8 -luuid -lrt -lcrypt -lpthread -ldl -lexpat -lssl -lcrypto -lnghttp2 -lxml2 -llua5.1 -licuuc -llzma -licudata -lz -Wl,--export-dynamic

# -------------------- prepare tools and environments --------------------------

bash $SACK/tools/copy_tools.sh $SACK .
objdump -d ./httpd.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# python3 send_request.restrict.py
# export AFL_NO_AFFINITY=1
# $SACK/AFL/afl-fuzz -d -c ./log/sack.conf -m none -i ./input/ -o ./output/ -t 1000+ -- ./httpd.fuzz -X -d /usr/local/apache2

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate
