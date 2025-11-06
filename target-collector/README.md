# Target Collector

The **Target Collector** is responsible for gathering indirect‑call (icall) targets during benign program execution.  
We adopt a lightweight strategy for generating test cases:

- When official test suites are available, we use them directly.  
- Otherwise, we provide minimal test cases that exercise basic program functionality.

For a given program, icall targets triggered by different oracles can be **merged** to form a better **sub‑ground truth** target set.  Different oracles cover different features of the program; merging them provides broader coverage.

You may follow either method for any target program to reproduce the target‑collection process.

---

## Collection Methods Per Program

| Program   | Target Collector Source           |
|-----------|----------------------------|
| Nginx     | Minimal test cases         |
| SQLite3   | Official test suites       |
| ProFTPD   | Minimal test cases         |
| Sudo      | Minimal test cases         |
| Apache    | Minimal test cases         |
| Wireshark | Minimal test cases         |
| V8        | Minimal test cases         |

---

## General Workflow for Indirect‑Call Target Collection

1. **Instrumentation & Execution**  
   After instrumentation, running the program will record icall pairs  
   **(ID, target address)** in:  
   ```
   ./log/address_log
   ```

2. **Collect Multiple Address Logs**  
   Different inputs (oracles) trigger different icall behaviors.  
   All `address_log` files are collected and placed under:  
   ```
   ./log/subgt-extract/
   ```
   These logs serve as the **sub‑ground truth** during substitution.

3. **Merge Icall Targets Across Oracles**  
   For the same program, results from multiple oracles can be merged to increase coverage.  
   We provide scripts to convert each `address_log` for the same oracle into a JSON file, and then merge them into a unified sub‑groundtruth JSON for the program.

The final processed JSON files we used are stored in:
```
/ae-sack/subgt/
```
Each target program/oracle has a reproduction guide in:
```
/ae-sack/script/{target_program}/{target_oracle}/subgt_collection.md
```

---

## Example: Collecting Sub‑Ground‑Truth Targets for **Nginx**

1. Navigate to each oracle folder (`/ae-sack/scripts/{target_program}/{target_oracle}`) and follow the instructions in its  
   `subgt_collection.md` to run the program (with one or two inputs).  
   Save each resulting `address_log` in the corresponding directory.

2. Convert each `address_log` to JSON using:
   ```
   /ae-sack/tools/address_to_json.py
   ```

3. Merge all oracle‑level JSON files into one program‑level JSON using:
   ```
   /ae-sack/tools/merge_json.py
   ```

4. Convert the final merged JSON back to an address_log in:
   ```
   log/subgt-extract/
   ```
   using:
   ```
   /ae-sack/tools/subgt_addresslog_gen.py
   ```

---

## Simplified Demonstration Experiments [For AE Evaluation]

Since full sub‑groundtruth collection involves multiple manual steps (running test cases, collecting logs, merging results), we provide two examples (One for minimal test case and one for test suite):

### 1. Minimal Test Case Example (Nginx / `n1_auth` Oracle)
We use the `Nginx-N1` oracle as a minimal demonstration.  
The icall targets collected from this oracle alone can reproduce all attacks found for that oracle, reducing evaluation manual overhead.

#### Setup
Navigate to the program directory:
```bash
cd /target/nginx/nginx-basic-auth/bin/sbin
```

Clean and prepare the target collection environment:
```bash
rm -rf log/subgt-extract
mkdir -p log/subgt-extract
```

---

#### First Input: Wrong Password

1. **In one terminal**, start the instrumented Nginx:
   ```bash
   ./nginx.fuzz
   ```

2. **In another terminal**, send a request with incorrect credentials:
   ```bash
   curl -u hello:wrong http://localhost
   ```

3. **Collect the address log**:
   ```bash
   mv log/address_log log/subgt-extract/fail
   ```

---

#### Second Input: Correct Password

1. **In one terminal**, start the instrumented Nginx again:
   ```bash
   ./nginx.fuzz
   ```

2. **In another terminal**, send a request with correct credentials:
   ```bash
   curl -u hello:123456 http://localhost
   ```

3. **Collect the address log**:
   ```bash
   mv log/address_log log/subgt-extract/success
   ```

---

####  Verification Methods


**Step 1: Generate visible JSON from collected logs**
```bash
python3 address_to_json.py \
  --address-dir ./log/subgt-extract/ \
  --line-log log/line_log \
  --func-map log/func_map \
  --output merged_icalls.json
```

Compare the generated `merged_icalls.json` with the reference:
```
/ae-sack/subgt/nginx/merged_icalls_n1.json
```

**Step 2: Use collected sub-ground truth to find attacks**

Run the attack engine with the collected sub-ground-truth log following the [`instruction`](../scripts/README.md).  
It should reproduce the same attacks as reported.

### 2. Official Test Suite Example (SQLite3)
We also provide the exact steps used for SQLite3, which depends on its complete official test suite. Because the procedure is complex and time‑consuming, we do not recommend reproducing it.

#### Test Suite-Based Collection

For SQLite3, we use the official test suites to trigger program logic and capture indirect calls. You can explore this in `/target-collection/`.

---

#### Step 1: Compile the Modified Collector

```bash
cd /target-collection/AFL-collectonly-sqlite/
make
cd /target-collection/AFL-collectonly-sqlite/llvm_mode_indirect_flip/
make
```

---

#### Step 2: Compile SQLite3 for Collection

```bash
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
```

---

#### Step 3: Create a Non-Root User

```bash
useradd -m -s /bin/bash tester
echo 'tester:tester' | chpasswd

// copy the whole folder in tester home folder, as test suites can only be run with non-root user

cp -r /target-collection/sqlite_target_collection /home/tester/
chown -R tester:tester /home/tester/sqlite_target_collection
chown -R tester:tester /collected_log_sqlite
```

---

#### Step 4: Run Test Suite with Instrumented `sqlite3`

```bash
su tester
cd /home/tester/sqlite_target_collection/
mv sqlite3 sqlite3.ori
mv sqlite3.fuzz sqlite3
./testfixture ./test/veryquick.test

// Collect Logs and Convert to JSON

objdump -d ./sqlite3 | grep ">:" > ./log/func_map
cp /collected_log_sqlite/address_log ./log/
cp /collected_log_sqlite/line_log ./log/
cd ./log/
cp /ae-sack/tools/address_to_json.py .
python3 address_to_json.py --address-log address_log --line-log line_log --func-map func_map --output merge_icalls.json
mv merge_icalls.json ../collected_target_part_1.json
```

---

#### Step 5: Repeat with `testfixture` Instrumentation

```bash
exit  # Return to root shell

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

//Collect Second Set of Logs

objdump -d ./testfixture.fuzz | grep ">:" > ./log/func_map
cp /collected_log_sqlite/address_log ./log/
cp /collected_log_sqlite/line_log ./log/
cd ./log/
cp /ae-sack/tools/address_to_json.py .
python3 address_to_json.py --address-log address_log --line-log line_log --func-map func_map --output merge_icalls.json
mv merge_icalls.json ../collected_target_part_2.json
```

---

#### Step 6: Merge JSON Files

```bash
cp /home/tester/sqlite_target_collection_2/collected_target_part_2.json /home/tester/sqlite_target_collection/
cp /ae-sack/tools/merge_json.py /home/tester/sqlite_target_collection/
cd /home/tester/sqlite_target_collection/
python3 merge_json.py collected_target_part_1.json collected_target_part_2.json merged_sqlite.json
```

You can now compare `merged_sqlite.json` with the reference version at:
```
/ae-sack/subgt/merged_sqlite.json
```
The result should be similar.