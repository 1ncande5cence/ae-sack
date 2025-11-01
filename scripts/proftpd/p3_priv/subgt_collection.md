# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
./proftpd.fuzz -n -c /target/proftpd/proftpd-priv/bin_oracle3_user_priv/proftpd.conf -d 5 -X -d 5 -X

python3 ftpreq_STOR.py
Ctrl + C

mv log/address_log log/subgt-extract/fail

## Input 2
./proftpd.fuzz -n -c /target/proftpd/proftpd-priv/bin_oracle3_user_priv/proftpd.conf -d 5 -X

python3 ftpreq_STOR_success.py
Ctrl + C

mv log/address_log log/subgt-extract/success

## Input 3
./proftpd.fuzz -n -c /target/proftpd/proftpd-priv/bin_oracle3_user_priv/proftpd.conf -d 5 -X

python3 ftpreq_STOR_success.py
Ctrl + C

mv log/address_log log/subgt-extract/success2

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
