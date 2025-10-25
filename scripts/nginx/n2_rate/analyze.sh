#!/bin/bash
set -euo pipefail 

# Script for Nginx rate limit N2
# use it in bin/sbin folder

# Step 0: Ask the user for mode
echo "What mode is this? [1] runtime-collect target [2] MLTA (static approximate) [3] TFA (static approximate)"
read -r mode_choice

if [ "$mode_choice" == "1" ]; then
    mode_suffix="runtime"
elif [ "$mode_choice" == "2" ]; then
    mode_suffix="MLTA"
elif [ "$mode_choice" == "3" ]; then
    mode_suffix="TFA"
else
    echo "Invalid choice. Please enter 1 2 or 3."
    exit 1
fi

# Step 1: Create a timestamped result directory
timestamp=$(date +"%Y%m%d%H%M%S")
result_dir="result.${timestamp}.${mode_suffix}"
mkdir -p "$result_dir"

# Step 2: Copy the entire log and output directory into result.(time)
cp -r log "$result_dir/"
cp -r output "$result_dir/"

# Step 3: Change to result.(time) and do further analysis

cd "$result_dir" || {
    echo "Failed to cd into $result_dir"
    exit 1
}

echo "Environment ready in $result_dir"


# full successful attack

awk '
/HTTP\/1.1" 200/ { ok[$1]++; all[$1]++; lines[$1] = lines[$1] $0 "\n" }
/HTTP\/1.1"/ && !/200/ { all[$1]++; lines[$1] = lines[$1] $0 "\n" }
END {
  for (k in all) {
    if (all[k] == 2 && ok[k] == 2)
      printf "%s", lines[k]
  }
}' ./log/host.access.log | grep -v 'HTTP/1.1" 200 0' | cut -d' ' -f1 | sort -u > full_success_attack.log


echo "full successful attack:"

cat full_success_attack.log | wc -l

# violation check (all the sub that violates the icall)

grep '^flip operation:' log/icall_violation_log | sed 's/^flip operation://' | sort -u > icall_violate_sub.log || true

# satisfied attack ( break oracles and doesn't violate the icall)

comm -23 <(sort full_success_attack.log) <(sort icall_violate_sub.log) > satisfied_attack.log

# unique successful attack (don't consider enter time)

cat satisfied_attack.log | awk -F'_' '{print $1"_"$2}' | sort -u > unique_attack.log
echo "unique attack:"
cat unique_attack.log | wc -l

# generate report 

python3 ../report.py satisfied_attack.log report_satisfied.txt
python3 ../report.py unique_attack.log report_unique.txt