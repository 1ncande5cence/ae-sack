# Script for Apache authentication A1


# -------------------- first dry-run to collect target ------------------------------------

# ./httpd.fuzz -X -d /usr/local/apache2

# in another terminal 
# curl -u song:secret http://localhost/private/
# mv log/address_log log/subgt-extract/success_log


# -------------------- do substitution --------------------------------------
# in current folder

# terminal 1
# python3 send_request.auth.py

# terminal 2
# export AFL_NO_AFFINITY=1
# export SACK=/ae-sack
# $SACK/AFL/afl-fuzz -d -c ./log/sack.conf -m none -i ./input/ -o ./output/ -t 1000+ -- ./httpd.fuzz -X -d /usr/local/apache2

# when substitution finish, stop the python script

# -------------------- result analysis --------------------------------------

# use analyze.sh at the ./bin/sbin/ folder

# the result is in the result.*/ folder report_satisfied.txt