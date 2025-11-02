#!/bin/bash
set -euo pipefail

# program preparation
#cp $1/scripts/apache/a1_auth/httpd.conf /usr/local/apache2/conf/httpd.conf


# subgt generation
cp $1/tools/subgt_addresslog_gen_apache.py $2
cp $1/tools/address_to_json.py $2
cp $1/subgt/apache/subgt.json $2

# oracle input
cp -r $1/scripts/apache/a2_waf/input $2
cp $1/scripts/apache/a2_waf/send_request.waf.py $2

# result analysis 
cp $1/scripts/apache/report.py $2
