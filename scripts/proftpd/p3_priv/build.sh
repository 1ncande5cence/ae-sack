#!/bin/bash
set -euo pipefail

# Script for Proftpd user-privilege P3

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
make clean
./configure --enable-ctrls --with-modules=mod_ban
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------

mkdir bin_oracle3_user_priv
cp proftpd bin_oracle3_user_priv/
cd bin_oracle3_user_priv
extract-bc proftpd
export EXTRA_LDFLAGS="-lcrypt -lc -ldl"
mkdir -p ./log
cp $SACK/scripts/proftpd/p3_priv/sack.conf ./log/
cp $SACK/scripts/proftpd/p3_priv/ban_line.list ./log/
cp $SACK/scripts/proftpd/p3_priv/ftpreq_STOR.py .
$SACK/AFL/afl-clang-fast-indirect-flip proftpd.bc -o proftpd.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/proftpd/p3_priv/copy_tools.sh $SACK .
objdump -d ./proftpd.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------

# -------------------- do substitution --------------------------------------
# in bin_oracle3_user_priv folder
# terminal 1
# python3 ftpreq_STOR.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# (this -c path and the path in the proftpd.conf need to be absolute path)
# for your proftpd.passwd, you need to modify the sack.conf system_command to add "chmod 600 /path/to/file/proftpd.passwd"
# for your user, you need to modify the sack.conf system_command to add "chown root:root /home/test"
# also add "chmod 755 /home/test"
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /methodology.new/proftpd-collection/proftpd/bin/proftpd.conf -d 5 -X


# -------------------- result analysis --------------------------------------

# use analyze.sh at the bin_safemode folder

# the result is in the result.*/ folder report_unique.txt
