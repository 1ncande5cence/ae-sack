#!/bin/bash
set -euo pipefail

# program preparation

cp $1/scripts/proftpd/p4_root/proftpd.conf $2

# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/proftpd/subgt.json $2

# oracle input
cp -r $1/scripts/proftpd/p4_root/input $2

# result analysis 
cp $1/scripts/proftpd/report.py $2
