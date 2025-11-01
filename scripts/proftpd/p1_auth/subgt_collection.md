# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
./proftpd.fuzz -n -c /target/proftpd/proftpd-auth/bin_oracle1_auth/proftpd.conf -d 5 -X

modify ftpreq_oracle1_improve.py
uncomment line 48 and comment line 49

python3 ftpreq_oracle1_improve.py
Ctrl + C

mv log/address_log log/subgt-extract/success

## Input 2
./proftpd.fuzz -n -c /target/proftpd/proftpd-auth/bin_oracle1_auth/proftpd.conf -d 5 -X

modify ftpreq_oracle1_improve.py
comment line 48 and uncomment line 49

python3 ftpreq_oracle1_improve.py
Ctrl + C

mv log/address_log log/subgt-extract/fail

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
