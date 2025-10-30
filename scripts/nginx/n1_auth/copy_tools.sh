#!/bin/bash
set -euo pipefail

# program preparation
cp $1/scripts/nginx/n1_auth/nginx.conf $2/../conf/nginx.conf


# subgt generation
cp $1/tools/subgt_addresslog_gen.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/nginx/subgt.json $2

# oracle input
cp -r $1/scripts/nginx/n1_auth/input $2
cp $1/scripts/nginx/n1_auth/send_request.py $2

# result analysis 
cp $1/scripts/nginx/report.py $2
