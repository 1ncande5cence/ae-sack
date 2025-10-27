#!/bin/bash
set -euo pipefail 

# Script for Wireshark Malform W1

# Some settings
export SACK=/ae-sack

# -------------------- build project with wllvm --------------------------------

export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
apt-get install -y qttools5-dev qttools5-dev-tools libqt5svg5-dev qtmultimedia5-dev
apt install -y software-properties-common
add-apt-repository ppa:okirby/qt6-backports -y
apt install -y libgl1-mesa-dev
apt install -y qt6-base-dev qt6-tools-dev qt6-tools-dev-tools qt6-l10n-tools libqt6core5compat6-dev
apt install -y libpcap-dev libgcrypt-dev libc-ares-dev libspeexdsp-dev flex bison
rm -rf build
cmake -B build -DENABLE_QT=OFF -DBUILD_wireshark=OFF -DENABLE_STATIC=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j$(nproc)

# -------------------- build flip binaries -----------------------------------

cd build/run/ 
extract-bc tshark

mkdir -p ./log
cp $SACK/scripts/wireshark/w1_malform/sack.conf ./log/
cp $SACK/scripts/wireshark/w1_malform/ban_line.list ./log/
$SACK/AFL/afl-clang-fast-indirect-flip tshark.bc -o tshark.fuzz -lpcap -lgmodule-2.0 -lpcre2-8 -lglib-2.0 -lcares -lgcrypt -lxml2 -lm -lnghttp2 -lz -ldl -lpthread -lpcre -lgpg-error -licuuc -llzma -licudata -Wl,--export-dynamic

# -------------------- prepare tools and environments --------------------------

bash $SACK/scripts/wireshark/w1_malform/copy_tools.sh $SACK .
objdump -d ./tshark.fuzz | grep ">:" > ./log/func_map
python3 subgt_addresslog_gen.py ./subgt.json
mkdir input
cp $SACK/scripts/wireshark/w1_malform/malformed.pcap input/

# -------------------- corpus is copied  ------------------------------------


# -------------------- do substitution --------------------------------------
# in ./build/run/ folder

# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m none -i ./input/ -o ./output/ -t 1000+ -- ./tshark.fuzz -r @@


# -------------------- result analysis --------------------------------------

# use analyze.sh at the bin/sbin/ folder

# the result is in the result.*/ folder report_unique.txt