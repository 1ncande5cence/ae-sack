# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
open target/nginx-rate-limit/bin/conf/nginx.conf 
and comment # limit_req zone=tem_min_limit nodelay;

./nginx.fuzz

python3 send_request_rate_limit.py
Ctrl + C

mv log/address_log log/subgt-extract/success

## Input 2
open target/nginx-rate-limit/bin/conf/nginx.conf 
and uncomment # limit_req zone=tem_min_limit nodelay;

./nginx.fuzz

python3 send_request_rate_limit.py
Ctrl + C

mv log/address_log log/subgt-extract/fail

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
