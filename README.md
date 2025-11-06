# ae-sack
artifact-evaluation version for SACK

We provide four docker images to do the evaluation, 
oracle constructor can be tested in any of the images
for target collector and attack engine, we pre-build the program and dependency,
they are located in different docker images, due to some tested program is using the global setting and may interfere other testing. you can select several to test
and verify the results.

## layout
Target programs and their corresponding oracles are separated into four Docker images, each containing a similar file layout:

| Docker Image           | Targeted Programs/Oracles                        |
|------------------------|------------------------------------------|
| `sack_main`    | Nginx (N1–N6), SQLite3 (Q1–Q2), ProFTPD (P1–P4), Wireshark (W1)|
| `sack_sudo`    | Sudo (U1–U3)                             |
| `sack_apache`  | Apache (A1–A5)                           |
| `sack_v8`  | V8 (V1)                           |


# Testing oracle constructor

follow README.md in /ae-sack/oracle-generation

# Testing target collector

follow README.md in /ae-sack/target-collector

# Testing attack engine

follow README.md in /ae-sack/scripts