# Script for Proftpd auth-required actions P4

# -------------------- do substitution --------------------------------------
# in ./bin_auth_required folder
# terminal 1
# python3 ftpreq_oracle4.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -m 100M -i ./input/ -o output/ -t 1000 -- ./proftpd.fuzz -n -c /target/proftpd/proftpd-root/bin_auth_required/proftpd.conf -d 5 -X

# when substitution finish, stop the python script

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin_auth_required folder

# the result is in the result.*/ folder report_satisfied.txt
