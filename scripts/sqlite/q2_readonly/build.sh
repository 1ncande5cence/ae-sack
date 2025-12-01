#!/bin/bash
set -euo pipefail 

# Script for SQLite3 readonly Q2

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt install -y tcl-dev
./configure 
rm -rf sqlite3
make -j$(nproc) 

# -------------------- build flip binaries -----------------------------------
rm -rf bin_readonly
mkdir bin_readonly
cp sqlite3 ./bin_readonly
cd ./bin_readonly
extract-bc sqlite3
export EXTRA_LDFLAGS="-lpthread -lz -lm -ldl -lreadline"
mkdir -p ./log
rm -rf oracle
mkdir oracle
cp $SACK/scripts/sqlite/q1_unsafe/sack.conf ./log/
cp $SACK/scripts/sqlite/q1_unsafe/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip sqlite3.bc -o sqlite3.fuzz $EXTRA_LDFLAGS

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/sqlite/q2_readonly/copy_tools.sh $SACK .
cp my_database_template.db my_database_noage.db
objdump -d ./sqlite3.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- corpus is copied through copy_tools.sh ------------------------------------



# -------------------- do substitution --------------------------------------

# in bin_readonly folder

# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sqlite3.fuzz -readonly my_database_noage.db


# -------------------- result analysis --------------------------------------

# use corresponding analyze.sh from /ae-sack/scripts/{target_program}/{target_oracle} in the directory workdir /target/sqlite/sqlite-readonly/bin_readonly folder

# the result is in the result.*/ folder report_satisfied.txt

