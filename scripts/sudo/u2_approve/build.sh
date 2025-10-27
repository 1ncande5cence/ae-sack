#!/bin/bash
set -euo pipefail 

# Script for Sudo extra approval  U2

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --enable-static-sudoers --enable-python --disable-shared-libutil --enable-openssl=no LDFLAGS="-static"

make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir -p src/bin
cp src/sudo src/bin/
cd src/bin
extract-bc sudo
export EXTRA_LDFLAGS="-lutil -lsudo_util -lcrypt -lpthread -lc -ldl -lz"

mkdir -p ./log
cp $SACK/scripts/sudo/u2_approve/sack.conf ./log/
cp $SACK/scripts/sudo/u2_approve/ban_line.list ./log/

$SACK/AFL/afl-clang-fast-indirect-flip sudo.bc -o sudo.fuzz -L/usr/local/libexec/sudo/ -Wl,-rpath, /usr/local/libexec/sudo/ $EXTRA_LDFLAGS

chmod 4755 ./sudo.fuzz

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/sudo/u2_approve/copy_tools.sh $SACK .
objdump -d ./sudo.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------


# -------------------- first dry-run to collect target ------------------------------------

./sudo.fuzz ls /root || true
mv log/address_log log/subgt-extract/success_log

# -------------------- do branch flipping --------------------------------------
# cd src/bin
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sudo.fuzz ls /root

# -------------------- result analysis --------------------------------------

# use analyze.sh at the bin/sbin/ folder

# the result is in the result.*/ folder report_unique.txt