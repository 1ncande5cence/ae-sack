# Attack Engine

The **Attack Engine** leverages the collected indirect-call targets and generated security oracles to perform function substitution attacks.

After each substitution, it checks whether the security oracle has been compromised and whether the CFI has been violated. Finally, it reports the candidate function substitution attacks.

---

## General Workflow

Target programs and their corresponding oracles are separated into three Docker images, each containing a similar file layout:

| Docker Image           | Targeted Programs                        |
|------------------------|------------------------------------------|
| `docker_image_main`    | Nginx (N1–N6), SQLite3 (Q1–Q2), ProFTPD (P1–P4), Wireshark (W1), V8 (V1) |
| `docker_image_sudo`    | Sudo (U1–U3)                             |
| `docker_image_apache`  | Apache (A1–A5)                           |

For each target oracle, the following directory contains scripts and dependencies:
```
/ae-sack/scripts/{target_program}/{target_oracle}/
```

Each test is executed within a corresponding runtime folder:
```
/target/{target_program}/{target_oracle}/
```

### Execution Steps
Run or follow the following commands in the corresponding runtime folder.

1. **[Optional] Build the program**  
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/build.sh
   ```
   This is optional because our docker image already pre-build the target programs.

2. **Run the Attack Engine**  
   Follow the instruction and the desired location in `run.sh` to start the attack engine, we don't make it an executable script because some programs rely on the interaction with the request sender and the sequence is important.
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/run.sh
   ```

3. **Collect and Analyze Results**
   Follow the instruction about the location to use `analyze.sh` in `run.sh`, use it at the correct location.  
   ```bash
   /ae-sack/scripts/{target_program}/{target_oracle}/analyze.sh
   ```

---

## Example: Testing Oracle N1 (Nginx)

1. Navigate to the target oracle folder:
   ```bash
   cd /target/nginx/nginx-basic-auth
   ```

2. **[Optional] Build the program:**
   ```bash
   /ae-sack/scripts/nginx/n1_auth/build.sh
   ```

3. **Run the attack engine:**
   Follow the instructions in:
   ```bash
   /ae-sack/scripts/nginx/n1_auth/run.sh
   ```

4. **Collect the result:**
   ```bash
   /ae-sack/scripts/nginx/n1_auth/analyze.sh
   ```

---

## 📊 Result Verification

You can verify the results in one of the following ways:

1. **Compare Attack Count**  
   Check whether the number of attacks matches the value reported in the paper’s Table.

2. **Compare Concrete Attacks**  
   Compare the collected attack logs with the metadata provided in the `/ae-sack/attack_metadata` directory.



tested program | tested oracle | tested image | tested location folder | build | run | analyze
Nginx             N1.            docker_image_main. /target/nginx/nginx-basic-auth , /ae-sack/scripts/nginx/n1_auth/build.sh | /ae-sack/scripts/nginx/n1_auth/run.sh | /ae-sack/scripts/nginx/n1_auth/analyze.sh

