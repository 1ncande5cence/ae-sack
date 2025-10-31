#!/bin/bash
set -euo pipefail
# program preparation
cp $1/scripts/nginx/n4_restrict/nginx.conf $2/../conf/nginx.conf


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/nginx/subgt.json $2

# oracle input
cp -r $1/scripts/nginx/n4_restrict/input $2
cp $1/scripts/nginx/n4_restrict/send_request_disable.py $2
cp $1/scripts/nginx/n4_restrict/send_request_disable_pass.py $2

# result analysis 
cp $1/scripts/nginx/report.py $2
