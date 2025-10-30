#!/bin/bash
set -euo pipefail


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/wireshark/subgt.json $2

# # oracle input  build.sh will generate it
# cp -r $1/scripts/wireshark/w1_malform/input $2


# result analysis 
cp $1/scripts/wireshark/report.py $2
