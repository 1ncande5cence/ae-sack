#!/bin/bash
set -euo pipefail 

# Script for V8 unsafe command V1

# Some settings
export SACK=/ae-sack

cd ..
export PATH="$PWD/depot_tools:$PATH"
cd v8

# -------------------- build project with wllvm --------------------------------

export CC="wllvm" CXX="wllvm++" BUILD_CC="wllvm" BUILD_CXX="wllvm++" LLVM_COMPILER=clang AR=llvm-ar NM=llvm-nm BUILD_AR=llvm-ar BUILD_NM=llvm-nm 
apt install -y bison cdbs curl flex g++ git python vim pkg-config ninja-build
gn gen x64.debug
cp $SACK/scripts/v8/v1_unsafe/args.gn x64.debug

ninja -C x64.debug "v8_monolith" "d8"

# -------------------- build flip binaries -----------------------------------

cd x64.debug
cp ./obj/libv8_monolith.a .
extract-bc d8

mkdir -p ./log
rm -rf oracle
mkdir oracle
cp $SACK/scripts/v8/v1_unsafe/sack.conf ./log/
cp $SACK/scripts/v8/v1_unsafe/ban_line.list ./log/
mkdir input
cp $SACK/scripts/v8/v1_unsafe/os.system.js ./input/
cp $SACK/scripts/v8/v1_unsafe/os.system.js .
cp $SACK/scripts/v8/v1_unsafe/test.js .
$SACK/AFL/afl-clang-fast-indirect-flip d8.bc -o d8.fuzz.pre -lpthread -lm -latomic -lstdc++ -lc -lgcc_s libv8_monolith.a

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/v8/v1_unsafe/copy_tools.sh $SACK .
pip install lief
python3 seg-change.py
chmod +x d8.fuzz
objdump -d ./d8.fuzz | grep ">:" > ./log/func_map
#python3 subgt_addresslog_gen.py ./subgt.json

# -------------------- generate subgt input ------------------------------------

# in x64.debug folder

# ./d8.fuzz --enable-os-system test.js
# mv log/address_log log/subgt-extract/success_log

# -------------------- do substitution --------------------------------------
# in x64.debug folder

# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m none -i ./input -o ./output/ -t 5000+ -- ./d8.fuzz @@


# -------------------- result analysis --------------------------------------

# use analyze.sh at the bin_safemode folder

# the result is in the result.*/ folder report_unique.txt

