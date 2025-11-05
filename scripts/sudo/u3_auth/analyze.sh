#!/bin/bash
set -euo pipefail 

# Script for Sudo authentication U3

#mode_suffix="runtime"

# Step 1: Create a timestamped result directory
timestamp=$(date +"%Y%m%d%H%M%S")
result_dir="result.${timestamp}.${mode_suffix}"
mkdir -p "$result_dir"

# Step 2: Copy the entire log and output directory into result.(time)
cp -r log "$result_dir/"
cp -r output "$result_dir/"
cp /var/log/sudo.log "$result_dir/"

# Step 3: Change to result.(time) and do further analysis

cd "$result_dir" || {
    echo "Failed to cd into $result_dir"
    exit 1
}

echo "Environment ready in $result_dir"


# full successful attack

grep -E "*test :$" sudo.log | cut -d" " -f1 > full_success_attack.log


echo "full successful attack (A0):"

cat full_success_attack.log | wc -l

# violation check (all the sub that violates the icall)

grep '^flip operation:' log/icall_violation_log | sed 's/^flip operation://' | sort -u > icall_violate_sub.log || true

# satisfied attack ( break oracles and doesn't violate the icall)

comm -23 <(sort full_success_attack.log) <(sort icall_violate_sub.log) > satisfied_attack.log

echo "pass CFI violation check attack (A1):"

cat satisfied_attack.log | wc -l

# unique successful attack (don't consider enter time)

cat satisfied_attack.log | awk -F'_' '{print $1"_"$2}' | sort -u > unique_attack.log
# echo "unique attack:"
# cat unique_attack.log | wc -l

# generate report 

python3 ../report.py satisfied_attack.log report_satisfied.txt
# python3 ../report.py unique_attack.log report_unique.txt


