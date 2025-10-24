#!/bin/bash 

# Script for Proftpd user-privilege P3

# Some settings
export VSACK=/vsack.new/vsack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O1" CXXFLAGS="-g -O1"

./configure --enable-ctrls --with-modules=mod_ban
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

mkdir bin_vsack_oracle3_user_priv 
cp proftpd bin_vsack_oracle3_user_priv/
cd bin_vsack_oracle3_user_priv 
extract-bc proftpd
export EXTRA_LDFLAGS="-lcrypt -lc -ldl"
mkdir -p ./log
cp $VSACK/scripts/proftpd/p3_priv/vsack.conf ./log/
cp $VSACK/scripts/proftpd/p3_priv/ban_line.list ./log/
$VSACK/viper/BranchForcer/afl-clang-fast-flip proftpd.bc -o proftpd.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $VSACK/viper/tools/copy_tools.sh $VSACK .
objdump -d ./proftpd.fuzz | grep ">:" > ./log/func_map

# -------------------- put your corpus here ------------------------------------

# NOTE: put your corpus for next step!
# mkdir corpus; 
# cp <your testcases> corpus/

# -------------------- do branch flipping --------------------------------------
# python3 ftpreq_STOR.py

# export AFL_NO_AFFINITY=1
# cd bin_vsack_oracle3_user_priv
# $VSACK/viper/BranchForcer/afl-fuzz -c ./log/vsack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /methodology.new/proftpd-collection/proftpd/bin/proftpd.conf -d 5 -X


# # -------------------- corruptibility assessment (auto) ------------------------

# # assess syscall-guard variables
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot br -- ./sqlite3_rate
# # assess arguments of triggered syscalls
# python3 auto_rator.py ./sqlite3.bc ./dot/temp.dot arg -- ./sqlite3_rate