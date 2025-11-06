# [Artifact Evaluation] SACK: Systematic Generation of Function Substitution Attacks Against Control-Flow Integrity

_function substitution_ attacks (_sub_ attacks): 
altering function pointers between CFI-allowed targets.

SACK can automatically modify control data to construct _sub_  attacks.

There are three main components:
* Oracle Constructor: 
Construct security-oriented oracles and produce
pairs of program inputs and expected security behaviors.

* Target Collector:
Dynamically record the indirect control-flow transfer (ICT)
targets during benign execution.

* Attack Engine (built on [AFL](https://github.com/google/AFL)):
Perform substitutions and security violation check, report
successful _sub_ attacks.


## AE Environment

We provide **four pre-built Docker images** for evaluating the **three** core components of our system: the **Oracle Constructor**, **Target Collector**, and **Attack Engine**. 

Each image packages specific pre-built target programs and their corresponding oracles. This separation avoids interference caused by conflicting global settings in certain programs.

Each image shares a similar directory layout, with this repository located at /ae-sack inside the container.

| Docker Image                | Targeted Programs/Oracles                                         | Size     |
|-----------------------------|-------------------------------------------------------------------|----------|
| `sackae/sack_main:latest`   | Nginx (N1–N6), SQLite3 (Q1–Q2), ProFTPD (P1–P4), Wireshark (W1)   | 19.8 GB  |
| `sackae/sack_sudo:latest`   | Sudo (U1–U3)                                                      | 3.6 GB   |
| `sackae/sack_apache:latest` | Apache (A1–A5)                                                    | 5.2 GB   |
| `sackae/sack_v8:latest`     | V8 (V1)                                                           | 10 GB    |


- **Oracle constructor**
  - Can be tested in **any** of the provided images.
  - `OPENAI_API_KEY` and network connection required.

- **Target collector** and **Attack engine**
  - The test environment are packaged into **separate Docker images**.
  - Choose the image(s) that correspond to the target programs/oracles you want to evaluate.

### Mapping Between Evaluation Components and File Structure

This table outlines the relationship between each tested oracle, the location of its corresponding scripts, the Docker image used for evaluation, and the associated experiment folder.
| Tested Oracle | Script Location                    | Tested Image      | Experiment Folder                |
|----------------|------------------------------------|-------------------|----------------------------------|
| Nginx-N1       | /ae-sack/scripts/nginx/n1_auth     | `sackae/sack_main:latest` | /target/nginx/nginx-basic-auth/  |
| Nginx-N2       | /ae-sack/scripts/nginx/n2_rate     | `sackae/sack_main:latest` | /target/nginx/nginx-rate-limit/  |
| Nginx-N3       | /ae-sack/scripts/nginx/n3_waf     | `sackae/sack_main:latest` | /target/nginx/nginx-waf/  |
| Nginx-N4       | /ae-sack/scripts/nginx/n4_restrict     | `sackae/sack_main:latest` | /target/nginx/nginx-disable-method/  |
| Nginx-N5       | /ae-sack/scripts/nginx/n5_log     | `sackae/sack_main:latest` | /target/nginx/nginx-log/  |
| SQLite3-Q1       | /ae-sack/scripts/sqlite/q1_unsafe     | `sackae/sack_main:latest` | /target/sqlite/sqlite-readonly/  |
| SQLite3-Q2       | /ae-sack/scripts/sqlite/q2_readonly     | `sackae/sack_main:latest` | /target/sqlite/sqlite-unsafe/  |
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


### How to use
- **Step 1: Select Docker Image(s)**
  - Choose one or more images based on the target components and oracles you wish to evaluate.

- **Step 2: Pull the Docker Image**
  ```bash
  docker pull sackae/sack_main:latest
  ```

- **Step 3: Create and Start a Container**
  ```bash
  docker run --cap-add=SYS_PTRACE \
             --name ae-sack-main \
             --security-opt seccomp=unconfined \
             -it sackae/sack_main:latest /bin/bash
  ```

- **Step 4: Follow the Provided Instructions to Run the Experiments**


## Instructions

- **Oracle Constructor**  
  Refer to the `README.md` in `/ae-sack/oracle-generation/` for instructions.

- **Target Collector**  
  Refer to the `README.md` in `/ae-sack/target-collector/` for detailed guidance on running target collection.

- **Attack Engine**  
  Follow the `README.md` in `/ae-sack/scripts/` to execute and validate attack generation experiments.

