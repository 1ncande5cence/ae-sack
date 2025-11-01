# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
./proftpd.fuzz -n -c /tmp/proftpd.conf  -d 5 -X

ftp localhost

test test 
quote SYST
exit

mv log/address_log log/subgt-extract/success

## Input 2
./proftpd.fuzz -n -c /tmp/proftpd.conf  -d 5 -X

python3 ftpreq_limit_oracle1.py

./proftpd.fuzz -n -c /tmp/proftpd.conf  -d 5 -X
./proftpd.fuzz -n -c /tmp/proftpd.conf  -d 5 -X


mv log/address_log log/subgt-extract/fail


then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
