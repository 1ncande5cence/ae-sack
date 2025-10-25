#!/bin/bash
set -euo pipefail
# program preparation
cp $1/scripts/nginx/n3_waf/nginx.conf $2/../conf/nginx.conf


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/subgt/nginx/subgt.json $2

# oracle input
cp -r $1/scripts/nginx/n3_waf/input $2
cp $1/scripts/nginx/n3_waf/send_request_waf.py $2

# result analysis 
cp $1/scripts/nginx/report.py $2
