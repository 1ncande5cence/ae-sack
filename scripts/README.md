# Attack Engine

The **Attack Engine** leverages the collected indirect-call targets and generated security oracles to perform function substitution attacks.

After each substitution, it checks whether the security oracle has been compromised and whether the CFI has been violated. Finally, it reports the candidate function substitution attacks.

---

## General Workflow

Target programs and their corresponding oracles are separated into four Docker images, each containing a similar file layout:

| Docker Image           | Targeted Programs/Oracles                        |
|------------------------|------------------------------------------|
| `sack_main`    | Nginx (N1–N6), SQLite3 (Q1–Q2), ProFTPD (P1–P4), Wireshark (W1)|
| `sack_sudo`    | Sudo (U1–U3)                             |
| `sack_apache`  | Apache (A1–A5)                           |
| `sack_v8`  | V8 (V1)                           |

For each target oracle, the following directory contains scripts and dependencies:
```
/ae-sack/scripts/{target_program}/{target_oracle}/
```

Each test is executed within a corresponding experiment folder:
```
/target/{target_program}/{target_oracle}/ or /target/{target_oracle}/
```
### Map between script and experiment folder

| Tested Oracle | Script Location                    | Tested Image      | Experiment Folder                |
|----------------|------------------------------------|-------------------|----------------------------------|
| Nginx-N1       | /ae-sack/scripts/nginx/n1_auth     | sack_main | /target/nginx/nginx-basic-auth/  |
| Nginx-N2       | /ae-sack/scripts/nginx/n2_rate     | sack_main | /target/nginx/nginx-rate-limit/  |
| Nginx-N3       | /ae-sack/scripts/nginx/n3_waf     | sack_main | /target/nginx/nginx-waf/  |
| Nginx-N4       | /ae-sack/scripts/nginx/n4_restrict     | sack_main | /target/nginx/nginx-disable-method/  |
| Nginx-N5       | /ae-sack/scripts/nginx/n5_log     | sack_main | /target/nginx/nginx-log/  |
| SQLite3-Q1       | /ae-sack/scripts/sqlite/q1_unsafe     | sack_main | /target/sqlite/sqlite-readonly/  |
| SQLite3-Q2       | /ae-sack/scripts/sqlite/q2_readonly     | sack_main | /target/sqlite/sqlite-unsafe/  |
| ProFTPD-P1       | /ae-sack/scripts/proftpd/p1_auth     | sack_main | /target/proftpd/proftpd-auth/  |
| ProFTPD-P2       | /ae-sack/scripts/proftpd/p2_limit     | sack_main | /target/proftpd/proftpd-limit/  |
| ProFTPD-P3       | /ae-sack/scripts/proftpd/p3_priv    | sack_main | /target/proftpd/proftpd-priv/  |
| ProFTPD-P4       | /ae-sack/scripts/proftpd/p4_root     | sack_main | /target/proftpd/proftpd-root/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u1_log     | sack_sudo | /target/sudo-log/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u2_approve     | sack_sudo | /target/sudo-approve/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u3_auth     | sack_sudo | /target/sudo-auth/  |
| Apache-A1       | /ae-sack/scripts/apache/a1_auth     | sack_apache | /target/httpd-auth/  |
| Apache-A2       | /ae-sack/scripts/apache/a2_waf     | sack_apache | /target/httpd-waf/  |
| Apache-A3       | /ae-sack/scripts/apache/a3_restrict     | sack_apache | /target/httpd-restrict/  |
| Apache-A4       | /ae-sack/scripts/apache/a4_log     | sack_apache | /target/httpd-log/  |
| Apache-A5       | /ae-sack/scripts/apache/a5_block     | sack_apache | /target/httpd-block/  |
| Wireshark-W1       | /ae-sack/scripts/wireshark/w1-malform     | sack_apache | /target/wireshark/w1-malform  |
| V8-V1       | /ae-sack/scripts/v8/v1_unsafe     | sack_v8 | /target/v8/v1_unsafe  |



### Execution Steps
Run or follow the following commands in the corresponding experiment folder.

1. **[Optional] Build the program**  
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/build.sh
   ```
   This is optional because our docker image already pre-build the target programs.

2. **Run the Attack Engine**  
   Follow the instructions and the specified working directory in `run.sh` to launch the attack engine. We do not provide it as a directly executable script because some programs require interaction with the request sender, and the execution sequence is critical.
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/run.sh
   ```

3. **Collect and Analyze Results**
   Follow the location instructions provided in `run.sh`, and ensure that `analyze.sh` is executed from the appropriate directory.
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/analyze.sh
   ```
   The output is written both to stdout and to a file named `report_satisfied.txt` within the `result.*/` directory.

---

## Example: Testing Oracle N1 (Nginx)

1. Navigate to the experiment folder:
   ```bash
   cd /target/nginx/nginx-basic-auth
   ```

2. **[Optional] Build the program:**
   This step is not required as we already pre-build the system in the image.
   ```bash
   /ae-sack/scripts/nginx/n1_auth/build.sh
   ```

3. **Run the attack engine:**
   Follow the instructions in:
   ```bash
   /ae-sack/scripts/nginx/n1_auth/run.sh
   ```
   Start the attack engine at the right location.
4. **Collect the result:**
   After finishing substitution, use the following script at the right location `./bin/sbin`, as suggested in `run.sh`
   ```bash
   /ae-sack/scripts/nginx/n1_auth/analyze.sh
   ```
   Get the result from stdout and also a file named `report_satisfied.txt` within the `result.*/` directory.

---

## Result Verification

You can verify the results in one of the following ways:

1. **Compare Attack Count**  
   Check whether the number of attacks matches the value reported in the paper’s Table.I (ion) and Table.III A0-A2.

2. **Compare Concrete Attacks**  
   Compare the collected attack logs in `report_satisfied.txt` with the metadata provided in the `/ae-sack/attack_metadata` directory. You can use `csvlook {target-program}-{target-oracle}.csv | less` to see the original attacks SACK discovered.

### Expected behavior

We assume the attack number and the concreate attack is similar to what we reported in the paper and what we provided in the `/ae-sack/attack_metadata` directory.

### Note on Reproduced Attack Numbers
The number of reproduced attacks may differ slightly (either higher or lower) from those reported in the paper. This variation is expected and can be attributed to several factors:

•	**Configuration or dependency changes**: The configuration files or dependencies changes may affect parsing logic and result in different SUB attacks.  
•	**Directory or layout simplification**: We restructured the layout or directories of some target programs for simplicity, which may also influence parsing behavior and attack visibility.  
•	**Merged attacks with identical targets**: Some attacks share the same original and substituted target functions; we merged such cases after confirming equivalence using gdb.  
•	**Removal of false positives**: A few false positives were manually identified and removed during the validation process.  
•	**Improved analysis scripts**: Compared to the original scripts, the updated analysis scripts better filter out false positives (e.g., distinguishing HTTP responses like 200 0 as non-attacks).  
•	**Different sub-ground truth sets**: The collected sub-ground truth (subgt) in the current artifact may differ slightly from what was used in the original experiments.  
•	**Non-deterministic substitutions**: Some function substitutions are inherently unstable and do not always succeed (e.g., sqlite3::exprNodeIsConstantOrGroupBy).

Nonetheless, the overall trends and conclusions remain consistent with those reported in the paper.


