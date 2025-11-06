# Script for Sudo logging U1

# -------------------- prepare tools and environments --------------------------

# 1. modify through visudo, should be the same as visudo.backup

# 2. cp sudo.conf
# export SACK=/ae-sack
# cp $SACK/scripts/sudo/u1_log/sudo.conf /etc/sudo.conf

# -------------------- first dry-run to collect target ------------------------------------

# in ./src/bin
# ./sudo.fuzz ls /root
# mv log/address_log log/subgt-extract/success_log

# -------------------- do substitution --------------------------------------
# in ./src/bin
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -c ./log/sack.conf -d -m 100M -i ./input/ -o ./output/ -t 1000+ -- ./sudo.fuzz ls /root

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# the result is in the result.*/ folder report_satisfied.txt