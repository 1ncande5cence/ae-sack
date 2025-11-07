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
### Mapping Between Evaluation Components and File Structure

This table outlines the relationship between each tested oracle, the location of its corresponding scripts, the Docker image used for evaluation, and the associated experiment folder.

| Tested Oracle | Script Location                    | Tested Image      | Experiment Folder                |
|----------------|------------------------------------|-------------------|----------------------------------|
| Nginx-N1       | /ae-sack/scripts/nginx/n1_auth     | `sackae/sack_main:latest` | /target/nginx/nginx-basic-auth/  |
| Nginx-N2       | /ae-sack/scripts/nginx/n2_rate     | `sackae/sack_main:latest` | /target/nginx/nginx-rate-limit/  |
| Nginx-N3       | /ae-sack/scripts/nginx/n3_waf     | `sackae/sack_main:latest` | /target/nginx/nginx-waf/  |
| Nginx-N4       | /ae-sack/scripts/nginx/n4_restrict     | `sackae/sack_main:latest` | /target/nginx/nginx-disable-method/  |
| Nginx-N5       | /ae-sack/scripts/nginx/n5_log     | `sackae/sack_main:latest` | /target/nginx/nginx-log/  |
| SQLite3-Q1       | /ae-sack/scripts/sqlite/q1_unsafe     | `sackae/sack_main:latest` | /target/sqlite/sqlite-unsafe/  |
| SQLite3-Q2       | /ae-sack/scripts/sqlite/q2_readonly     | `sackae/sack_main:latest` | /target/sqlite/sqlite-readonly/  |
| ProFTPD-P1       | /ae-sack/scripts/proftpd/p1_auth     | `sackae/sack_main:latest` | /target/proftpd/proftpd-auth/  |
| ProFTPD-P2       | /ae-sack/scripts/proftpd/p2_limit     | `sackae/sack_main:latest` | /target/proftpd/proftpd-limit/  |
| ProFTPD-P3       | /ae-sack/scripts/proftpd/p3_priv    | `sackae/sack_main:latest` | /target/proftpd/proftpd-priv/  |
| ProFTPD-P4       | /ae-sack/scripts/proftpd/p4_root     | `sackae/sack_main:latest` | /target/proftpd/proftpd-root/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u1_log     | `sackae/sack_sudo:latest` | /target/sudo-log/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u2_approve     | `sackae/sack_sudo:latest` | /target/sudo-approve/  |
| Sudo-U1       | /ae-sack/scripts/sudo/u3_auth     | `sackae/sack_sudo:latest` | /target/sudo-auth/  |
| Apache-A1       | /ae-sack/scripts/apache/a1_auth     | `sackae/sack_apache:latest`| /target/httpd-auth/  |
| Apache-A2       | /ae-sack/scripts/apache/a2_waf     | `sackae/sack_apache:latest`| /target/httpd-waf/  |
| Apache-A3       | /ae-sack/scripts/apache/a3_restrict     | `sackae/sack_apache:latest`| /target/httpd-restrict/  |
| Apache-A4       | /ae-sack/scripts/apache/a4_log     | `sackae/sack_apache:latest`| /target/httpd-log/  |
| Apache-A5       | /ae-sack/scripts/apache/a5_block     | `sackae/sack_apache:latest`| /target/httpd-block/  |
| Wireshark-W1       | /ae-sack/scripts/wireshark/w1-malform     | `sackae/sack_apache:latest`| /target/wireshark/w1-malform  |
| V8-V1       | /ae-sack/scripts/v8/v1_unsafe     | `sackae/sack_v8:latest` | /target/v8/v1_unsafe  |



### Execution Steps
Run or follow the following commands in the corresponding experiment folder.

1. **[Optional] Build the program**  
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/build.sh
   ```
   This is optional because our docker image already pre-build the target programs.

2. **Run the Attack Engine**  
   Follow the instructions and the specified working directory in `run.readme` to launch the attack engine. We do not provide it as a directly executable script because some programs require interaction with the request sender, and the execution sequence is critical.
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/run.readme
   ```

3. **Collect and Analyze Results**
   Follow the location instructions provided in `run.readme`, and ensure that `analyze.sh` is executed from the appropriate directory.
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
   /ae-sack/scripts/nginx/n1_auth/run.readme
   ```
   Start the attack engine at the right location.
4. **Collect the result:**
   After finishing substitution, use the following script at the right location `/target/nginx/nginx-basic-auth/bin/sbin`, as suggested in `run.readme`
   ```bash
   /ae-sack/scripts/nginx/n1_auth/analyze.sh
   ```
   Get the result from stdout and also a file named `report_satisfied.txt` within the `result.*/` directory.

---

## Result Verification

You can verify the results in one of the following ways:

1. **Compare Attack Count**  
   Check whether the number of generated attacks aligns with the values reported in Table I (ion) and Table III (A0–A1) of the paper.

2. **Compare Concrete Attacks**  
   Compare the collected attack logs in `report_satisfied.txt` with the metadata provided in the `/ae-sack/attack_metadata` directory. You can use `csvlook {target-program}-{target-oracle}.csv | less` to see the original attacks SACK discovered.

### Expected behavior

We assume the attack number and the concreate attack is similar to what we reported in the paper and what we provided in the `/ae-sack/attack_metadata` directory.

### Note on Reproduced Attack Numbers
The number of reproduced attacks may differ slightly (either higher or lower) from those reported in the paper. This variation is expected and can be attributed to several factors:

•  **Configuration and Directory Simplification**: We simplified the configuration files and restructured the directory layouts of certain target programs to improve clarity and consistency. These changes may affect parsing logic and could lead to differences in SUB attack visibility or behavior.  
•	**Merged attacks with identical targets**: Some attacks share the same original and substituted target functions; we merged such cases after confirming equivalence using gdb.  
•	**Removal of false positives**: A few false positives were manually identified and removed during the validation process.  
•	**Improved analysis scripts**: Compared to the original scripts, the updated analysis scripts better filter out false positives (e.g., distinguishing HTTP responses like 200 0 as non-attacks).  
•	**Different sub-ground truth sets**: The collected sub-ground truth (subgt) in the current artifact may differ slightly from what was used in the original experiments.  
•	**Non-deterministic substitutions**: Some function substitutions are inherently unstable and do not always succeed (e.g., sqlite3::exprNodeIsConstantOrGroupBy).

Nonetheless, the overall trends and conclusions remain consistent with those reported in the paper.


