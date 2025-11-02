# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
./httpd.fuzz -X -d /usr/local/apache2

for send_request.restrict.py, comment line 13 and uncomment line 12

mv log/address_log log/subgt-extract/success

## Input 2
./httpd.fuzz -X -d /usr/local/apache2

for send_request.restrict.py, comment line 13 and uncomment line 12

mv log/address_log log/subgt-extract/fail

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
