#!/bin/bash

# Script for Proftpd auth-required actions P4

echo "Based on the result of P1, please cp P1 results to another folder (result.xxx.mem.p4)"
echo "Please execute the following code manually in the new result folder"
exit 1


# full successful attack

grep -rl "dir_check_full" ./oracle/ | xargs grep -L "/home/test" | cut -d"/" -f3 | sort -u > success.log

# filter out the case that end with _100_101, means doesn't reach the branch

grep -a -v '_100_101$' success.log > full_success_attack.log

echo "full successful attack:"

cat full_success_attack.log | wc -l

# unique successful attack (don't consider enter time)

cat full_success_attack.log | cut -d'_' -f1 | sort -u > unique_attack.log

echo "unique attack branch:"

cat unique_attack.log | wc -l


