# Attack Engine

The **Attack Engine** leverage the collected indirect call targets and generated security oracles to perform function substitution attacks.

After each substitution, it will record whether the security oracles has been compromised and the CFI has been violated. Finally, it will report the candidate
function substitution attacks.

## General Workflow for Attack Engine

we seperate the target programs and oracles in three seperate images, listed below,
in every image the file structure is similar.

layout
docker_image_main.      for Nginx (N1-N6), SQLite3 (Q1-Q2), ProFTPD (P1-P4), Wireshark (W1), V8 (V1)
docker_image_sudo.      for Sudo (U1-U3)
docker_image_apache.    for Apache (A1-A5)

For each target program oracles,
/ae-sack/scripts/{target_program}/{target_oracle}/ list the scripts and dependency needed.

there is a folder called /{target}/{target_oracle} where the experiment should run in the folder.

1) build the program (not necessary needed, as we already pre-build the target program)
run /ae-sack/scripts/{target_program}/{target_oracle}/build.sh in the folder

2) run the attack engine
follow /ae-sack/scripts/{target_program}/{target_oracle}/run.sh in the folder

3) collect the result
run /ae-sack/scripts/{target_program}/{target_oracle}/analyze.sh in the folder

here is a table show where to test which oracle

tested program | tested oracle | tested image | tested location folder | build | run | analyze
Nginx             N1.            docker_image_main. /target/nginx/nginx-basic-auth , /ae-sack/scripts/nginx/n1_auth/build.sh | /ae-sack/scripts/nginx/n1_auth/run.sh | /ae-sack/scripts/nginx/n1_auth/analyze.sh


## Example: Testing N1

1. go to the target oracle location
cd /target/nginx/nginx-basic-auth

2. [Optional] build the program
in /target/nginx/nginx-basic-auth, execute the script /ae-sack/scripts/nginx/n1_auth/build.sh

3. Run the attack engine 
follow the instruction provided in /ae-sack/scripts/nginx/n1_auth/run.sh and run the command

4. Collect the result
in /target/nginx/nginx-basic-auth, execute the script /ae-sack/scripts/nginx/n1_auth/analyze.sh


## result verification

the attack can be measure with one of the following method:

1. Check the attack number with what present in the paper Table x

2. compare the concreate attack data with the metadata we provided 