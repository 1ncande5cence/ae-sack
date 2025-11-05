# Target Collector

Target collector is used to collect indirect call targets during benign program execution.
To collect indirect call targets, we adopt a lightweight strategy to identify test cases.
When official test suites are available, we utilize them directly. 
Otherwise, we use minimal test cases that exercise basic program functionality.

For the same program, the indirect call triggered through different oracles can be merged together to represent
the sub-ground truth indirect call targets. As different oracle input targets at different features of the programs.

As discussed above, for each target programs, we take one of the two ways to collect icall targets, you can test on any target programs reproduce the process of
target collector.

Detailed collection method:

Nginx - minimal test cases
SQLite3 - official test suites
ProFTPD - minimal test cases
Sudo - minimal test cases
Apache - minimal test cases
Wireshark - minimal test cases
V8 - minimal test cases

General theory of indirect call target collection:
1. After instrumentation, when dynamic running the target program and trigger indirect call, indirect call pairs (ID and target address) will be recored in /log/address_log,
2. Different input will trigger different address_log, we collect these address_log and store in log/subgt-extract/ folder, during substitution, the attack engine will leverage the address_log in log/subgt-extract as sub-ground truth
3. For different oracles of the same programs, it is able to merge the result together and serve as the ground truth for this program to increase the sub-ground truth, so, we have merging scripts that can turn address_log of each oracle in to a json file, then merge these json file to generate the sub-ground truth json file for the program. 


the json file in /ae-sack/subgt/ folder is the result after the above process, with input to reproduce them in the /ae-sack/script/{target_program}/{target_oracle}/subgt_collection.md. 

For example, to collect sub-ground truth targets for Nginx, you should do the following 

1. go to each programs location and follow subgt_collection.md to run the program with one or two input, and put the address_log in the corresponding folder
2. use /ae-sack/tools/address_to_json.py to conver these address_log into json file
3. use /ae-sack/tools/merge_json.py to merge the json files from each oracle in nginx into one json file
4. use /ae-sack/tools/subgt_addresslog_gen.py to conver the final json file in to address_log in log/subgt-extract/ folder

Since the process involves many human operations like use test cases, collect indirect call targets and merge results. 
We design two simple experiment so that you can quickly know the process and confirm the result.
For collection method using minimal test cases, we select nginx/n1_auth oracle, 
as the targets collected from this oracle can already reproduce all the attack we find for this oracles, 
therefore reduce the effort to merge other oracles in nginx.

For collection method using official test suites, we describe the method we use for SQLite3.




1) use minimal test cases 
For most of the tested programs (except SQLite3), we use minimal test cases that exercise basic program functionality,
we use subgt_collection.md in each oracle to represent how to collect the targets.

Here is an example about how to collect the indirect call targets and use it as sub-ground truth

see /ae-sack/scripts/nginx/n1_auth/subgt_collection.md



2) use test suites.
For SQLite3, we use test suites to achieve the collection.

go to /target-collecton/ to see how we collect the targets using test suites.

1. compile collection code
we modify our original target collector code to support test suites
```
cd /target-collection/AFL-collectonly-sqlite/
make
cd /target-collection/AFL-collectonly-sqlite/llvm_mode_indirect_flip/
make
```

2. compile SQLite3

```
cd /target-collection/sqlite_target_collection/
apt-get install -y tcl tcl-dev
export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
./configure --with-tcl=/usr/lib/tcl8.6
make testfixture
make sqlite3

export CC=/target-collection/AFL-collectonly-sqlite/afl-clang-fast-indirect-flip
export EXTRA_LDFLAGS="-lpthread -lz -lm -ldl -lreadline"
extract-bc sqlite3

mkdir /collected_log_sqlite
$CC sqlite3.bc -o sqlite3.fuzz $EXTRA_LDFLAGS

// create a user tester

useradd -m -s /bin/bash tester
echo 'tester:tester' | chpasswd

// copy the whole folder in tester home folder, as test suites can only be run with non-root user

cp -r /target-collection/sqlite_target_collection /home/tester/
chown -R tester:tester /home/tester/sqlite_target_collection
chown -R tester:tester /collected_log_sqlite

su tester
cd /home/tester/sqlite_target_collection/
mv sqlite3 sqlite3.ori
mv sqlite3.fuzz sqlite3
./testfixture ./test/veryquick.test

objdump -d ./sqlite3 | grep ">:" > ./log/func_map
cp /collected_log_sqlite/address_log ~/sqlite_target_collection/log/
cp /collected_log_sqlite/line_log ~/sqlite_target_collection/log/
cd ~/sqlite_target_collection/log/
cp /ae-sack/tools/address_to_json.py .
python3 address_to_json.py --address-log address_log --line-log line_log --func-map func_map --output merge_icalls.json
mv merge_icalls.json ../collected_target_part_1.json

// back to root terminal
cd /target-collection/sqlite_target_collection
export CC=wllvm CXX=wllvm++ LLVM_COMPILER=clang CFLAGS="-g -O0" CXXFLAGS="-g -O0"
./configure --enable-debug
rm testfixture
make testfixture
extract-bc testfixture
export CC=/target-collection/AFL-collectonly-sqlite/afl-clang-fast-indirect-flip
export EXTRA_LDFLAGS="-lpthread -lz -lc -ldl -lm -ltcl8.6"
$CC testfixture.bc -o testfixture.fuzz $EXTRA_LDFLAGS

// copy the whole folder in tester home folder, as test suites can only be run with non-root user

cp -r /target-collection/sqlite_target_collection /home/tester/sqlite_target_collection_2
chown -R tester:tester /home/tester/sqlite_target_collection_2
chown -R tester:tester /collected_log_sqlite

su tester
cd /home/tester/sqlite_target_collection_2/
mv sqlite3.ori sqlite3
./testfixture.fuzz ./test/veryquick.test

objdump -d ./testfixture.fuzz | grep ">:" > ./log/func_map
cp /collected_log_sqlite/address_log ~/sqlite_target_collection_2/log/
cp /collected_log_sqlite/line_log ~/sqlite_target_collection_2/log/
cd ~/sqlite_target_collection_2/log/
cp /ae-sack/tools/address_to_json.py .
python3 address_to_json.py --address-log address_log --line-log line_log --func-map func_map --output merge_icalls.json
mv merge_icalls.json ../collected_target_part_2.json

// now, merge collected_target_part_1.json and collected_target_part_2.json and use it as sub-groundtruth for SQLite3

cp /home/tester/sqlite_target_collection_2/collected_target_part_2.json /home/tester/sqlite_target_collection/
cp /ae-sack/tools/merge_json.py /home/tester/sqlite_target_collection/
cd /home/tester/sqlite_target_collection/ 
python3 merge_json.py collected_target_part_1.json collected_target_part_2.json merged_sqlite.json

// you can diff the result between /ae-sack/subgt/merged_sqlite.json, the result should be similar

```


