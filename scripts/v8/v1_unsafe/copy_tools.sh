#!/bin/bash
set -euo pipefail

# program preparation


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
# cp $1/subgt/v8/subgt.json $2  (todo subgt)

# oracle input ( provided by build.sh)
cp $1/scripts/v8/v1_unsafe/seg-change.py $2


# result analysis 
cp $1/scripts/v8/report.py $2
