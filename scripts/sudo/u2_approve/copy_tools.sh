#!/bin/bash
set -euo pipefail


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/sudo/subgt.json $2

# oracle input
cp -r $1/scripts/sudo/u2_approve/input $2

# result analysis 
cp $1/scripts/sudo/report.py $2
