# Target Collector

Target collector is used to collect indirect call targets during benign program execution.
To collect indirect call targets, we adopt a lightweight strategy to identify test cases.
When official test suites are available, we utilize them directly. 
Otherwise, we use minimal test cases that exercise basic program functionality.

For the same program, the indirect call triggered through different oracles can be merged together to represent
the sub-ground truth indirect call targets. As different oracle input targets at different features of the programs.

As discussed above, we take two ways to collect icall targets, reviewers can select any of them to reproduce the process of
target collector.

1) use minimal test cases 
For rest of the programs, we use minimal test cases that exercise basic program functionality,
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


