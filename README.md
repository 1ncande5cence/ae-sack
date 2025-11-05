# ae-sack
artifact-evaluation version for SACK

We provide three docker images to do the evaluation, 
oracle constructor can be tested in any of the images
for target collector and attack engine, we pre-build the program and dependency,
they are located in different docker images, due to some tested program is using the global setting and may interfere other testing. you can select several to test
and verify the results.

## layout
docker_image_main.      for Nginx (N1-N6), SQLite3 (Q1-Q2), ProFTPD (P1-P4), Wireshark (W1), V8 (V1)
docker_image_sudo.      for Sudo (U1-U3)
docker_image_apache.    for Apache (A1-A5)

in all three images, the layout is similar.

# Testing oracle constructor

follow README.md in /ae-sack/oracle-generation

# Testing target collector

follow README.md in /ae-sack/target-collector

# Testing attack engine

follow README.md in /ae-sack/scripts