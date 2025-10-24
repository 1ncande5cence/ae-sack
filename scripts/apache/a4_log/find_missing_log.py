# compare_ids.py

probe_file = "log/probe_apache_log"
access_file = "access_log"
output_file = "only_in_probe.log"

def extract_ids(path):
    ids = set()
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            first_field = line.split()[0]  # take first token before space
            ids.add(first_field)
    return ids

# Get unique IDs from both files
probe_ids = extract_ids(probe_file)
access_ids = extract_ids(access_file)

# IDs that are in probe but not in access
only_in_probe = sorted(probe_ids - access_ids)

# Write results
with open(output_file, "w", encoding="utf-8") as out:
    for id_ in only_in_probe:
        out.write(id_ + "\n")

print(f"Done. {len(only_in_probe)} IDs written to {output_file}")