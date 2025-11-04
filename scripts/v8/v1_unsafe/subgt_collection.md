# Collect the Subgt

mkdir log/subgt-extract

## Input 1
./d8.fuzz --enable-os-system test.js

mv log/address_log log/subgt-extract/success_log

## Input 2
./d8.fuzz input/os.system.js

mv log/address_log log/subgt-extract/fail

then, the system is able to run,
to see the collected subgt clearly,
you can use :
python3 address_to_json.py --address-dir ./log/subgt-extract/ --line-log log/line_log --func-map log/func_map --output merged_icalls.json
