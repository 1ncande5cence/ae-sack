#!/bin/bash
set -euo pipefail

# program preparation


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/subgt/sqlite/subgt.json $2

# oracle input
cp -r $1/scripts/sqlite/q1_unsafe/input $2

# result analysis 
cp $1/scripts/sqlite/report.py $2
