#!/bin/bash
set -euo pipefail 

# Script for Proftpd auth P1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"

./configure --enable-ctrls --with-modules=mod_ban
make clean
make -j$(nproc)

# -------------------- build flip binaries -----------------------------------
rm -rf bin_oracle1_auth
mkdir bin_oracle1_auth
cp proftpd bin_oracle1_auth/
cd bin_oracle1_auth
extract-bc proftpd
export EXTRA_LDFLAGS="-lcrypt -lc -ldl"
mkdir -p ./log
cp $SACK/scripts/proftpd/p1_auth/sack.conf ./log/
cp $SACK/scripts/proftpd/p1_auth/ban_line.list ./log/
cp $SACK/scripts/proftpd/p1_auth/ftpreq_oracle1_improve.py .
$SACK/AFL/afl-clang-fast-indirect-flip proftpd.bc -o proftpd.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

# the following command have been done in this container to setup the environment:

# generate username and password  (test test; ftp ftp)

# adduser test  (passwd test)
#./contrib/ftpasswd --passwd --name test --uid=1001 --gid=1001 --home=/home/test --shell=/bin/bash --file=/target/proftpd/proftpd.passwd test
# (passwd test)

# mkdir -p /usr/local/var/proftpd

bash $SACK/scripts/proftpd/p1_auth/copy_tools.sh $SACK .
objdump -d ./proftpd.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json
rm -rf oracle
mkdir oracle
# -------------------- corpus is copied through copy_tools.sh ------------------------------------

# -------------------- do substitution --------------------------------------
# in bin_oracle1_auth folder
# terminal 1 
# python3 ftpreq_oracle1_improve.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack

# for your proftpd.passwd, you need to modify the sack.conf system_command to add "chmod 600 /path/to/file/proftpd.passwd"

# (this -c path and the path in the proftpd.conf need to be absolute path)
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /target/proftpd/proftpd-auth/bin_oracle1_auth/proftpd.conf -d 5 -X


# -------------------- result analysis --------------------------------------

# use corresponding analyze.sh from /ae-sack/scripts/{target_program}/{target_oracle} in the directory workdir /target/proftpd/proftpd-auth/bin_oracle1_auth folder

# the result is in the result.*/ folder report_satisfied.txt
