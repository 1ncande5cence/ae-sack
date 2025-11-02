# Collect the Subgt

We already generate subgt-extract in build through subgt.json,
but you can try to reproduce the target we collect

rm -rf log/subgt-extract
mkdir log/subgt-extract

## Input 1
./tshark.fuzz -r input/malformed.pcap

mv log/address_log log/subgt-extract/fail

## Input 2
./tshark.fuzz -r benign.pcap

mv log/address_log log/subgt-extract/success

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
