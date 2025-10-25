from collections import Counter

# Define file paths
probe_log_path = "./log/probe_nginx_log"
access_log_path = "./log/host.access.log"
output_file_path = "./log/missing_entries.log"

# Step 1: Process probe_nginx_log to only keep entries that appear exactly twice
with open(probe_log_path, "r") as probe_file:
    raw_probe_lines = [line.strip() for line in probe_file if line.strip()]
    probe_counter = Counter(raw_probe_lines)

# Keep only entries that appear exactly twice
probe_entries = {line.split()[0] for line, count in probe_counter.items() if count == 2}

# Step 2: Process host.access.log and deduplicate based on first column
with open(access_log_path, "r", encoding="utf-8", errors="ignore") as access_file:
    access_entries = {line.split()[0] for line in access_file if line.strip()}

# Step 3: Find probe entries missing from access log
missing_entries = probe_entries - access_entries

# Step 4: Output missing entries
for entry in missing_entries:
    print(entry)

with open(output_file_path, "w") as output_file:
    for entry in sorted(missing_entries):
        output_file.write(entry + "\n")
