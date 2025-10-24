#!/bin/bash 

# Script for Apache Restrict Method A3

# Step 0: Ask the user for mode
echo "What mode is this? [1] branchonly [2] mem-modification"
read -r mode_choice

if [ "$mode_choice" == "1" ]; then
    mode_suffix="branchonly"
elif [ "$mode_choice" == "2" ]; then
    mode_suffix="mem"
else
    echo "Invalid choice. Please enter 1 or 2."
    exit 1
fi

# Step 1: Create a timestamped result directory
timestamp=$(date +"%Y%m%d%H%M%S")
result_dir="result.${timestamp}.${mode_suffix}"
mkdir -p "$result_dir"

# Step 2: Copy the entire log and output directory into result.(time)
cp -r log "$result_dir/"
cp -r output "$result_dir/"
cp /usr/local/apache2/logs/access_log "$result_dir/"

# Step 3: Change to result.(time) and do further analysis

cd "$result_dir" || {
    echo "Failed to cd into $result_dir"
    exit 1
}

echo "Environment ready in $result_dir"


# full successful attack

grep 'HTTP/1.1" 200' access_log | awk '{print $1}' | sort -u > success.log

# filter out the case that end with _100_101, means doesn't reach the branch

grep -a -v '_100_101$' success.log > full_success_attack.log

echo "full successful attack:"

cat full_success_attack.log | wc -l

# unique successful attack (don't consider enter time)

cat full_success_attack.log | cut -d'_' -f1 | sort -u > unique_attack.log

echo "unique attack branch:"

cat unique_attack.log | wc -l


