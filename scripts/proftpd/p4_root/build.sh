#!/bin/bash 

# Script for Proftpd auth-required actions P4

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-ctrls --with-modules=mod_ban
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

mkdir bin_vsack_oracle1_auth
cp proftpd bin_vsack_oracle1_auth/
cd bin_vsack_oracle1_auth
extract-bc proftpd
export EXTRA_LDFLAGS="-lcrypt -lc -ldl"
mkdir -p ./log
cp $SACK/scripts/proftpd/p4_root/sack.conf ./log/
cp $SACK/scripts/proftpd/p4_root/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip proftpd.bc -o proftpd.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/tools/copy_tools.sh $SACK .
objdump -d ./proftpd.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# python3 ftpreq_oracle1_improve.py

# export AFL_NO_AFFINITY=1
# cd bin_vsack_oracle1_auth
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /methodology.new/proftpd-collection/proftpd/bin/proftpd.conf -d 5 -X


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate