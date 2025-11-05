#!/bin/bash
set -euo pipefail 

# Script for Sudo authentication U3

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y build-essential libtool libpcre3 libpcre3-dev zlib1g-dev openssl
./configure --disable-shared --disable-shared-libutil --enable-static-sudoers

make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------

mkdir -p src/bin
cp src/sudo src/bin/
cd src/bin
extract-bc sudo
export EXTRA_LDFLAGS="-lutil -lsudo_util -lcrypt -lpthread -lc -ldl -lz -lssl -lcrypto"

mkdir -p ./log
cp $SACK/scripts/sudo/u3_auth/sack.conf ./log/
cp $SACK/scripts/sudo/u3_auth/ban_line.list ./log/

$SACK/AFL/afl-clang-fast-indirect-flip sudo.bc -o sudo.fuzz -L/usr/local/libexec/sudo/ -Wl,-rpath, /usr/local/libexec/sudo/ $EXTRA_LDFLAGS

chmod 4755 ./sudo.fuzz

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/sudo/u3_auth/copy_tools.sh $SACK .
objdump -d ./sudo.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# modify through visudo, should be the same as visudo.backup
cp $SACK/scripts/sudo/u3_auth/sudo.conf /etc/sudo.conf

# -------------------- corpus is copied through copy_tools.sh ------------------------------------


# -------------------- first dry-run to collect target ------------------------------------

# ./sudo.fuzz -S ls /root
# mv log/address_log log/subgt-extract/success_log

# -------------------- do subsititute --------------------------------------
# cd src/bin
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sudo.fuzz -S ls /root

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# the result is in the result.*/ folder report_satisfied.txt