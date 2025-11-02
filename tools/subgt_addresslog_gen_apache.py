import json
import re
import struct
import os
import glob
import sys
import shutil

if len(sys.argv) < 2:
    print("Usage: python3 subgt_addresslog_gen.py <json_file>")
    sys.exit(1)


# # Step 0: generate func_map
# fuzz_files = glob.glob("./*.fuzz")
# if fuzz_files:
#     fuzz_file = fuzz_files[0]
#     print(f"[Step 1] Generating function map from {fuzz_file} using objdump...")
#     os.system(f"objdump -d {fuzz_file} | grep '>:' > ./log/func_map")
#     print("Function map generated and saved to ./log/func_map")


# --- Step 1: Build a mapping from "line" (file:line string) to ID from log/line_log ---

print(f"\n[Step 1] Generating subgt_address_log...")

line_log_map = {}  # maps "file:line" -> [id1, id2, ...]
with open("./log/line_log", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        tokens = line.split(maxsplit=1)
        if len(tokens) != 2:
            continue
        id_str, file_line = tokens
        try:
            id_int = int(id_str)
        except ValueError:
            continue
        # append (create list if first time)
        line_log_map.setdefault(file_line, []).append(id_int)

# --- Step 1.1: Build a mapping from function names to their hex addresses from log/func_map ---
func_map = {}
with open("./log/func_map", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        # Each line in func_map looks like:
        #    0000000000556560 <ngx_http_script_copy_len_code>:
        tokens = line.split()
        if len(tokens) < 2:
            continue
        hex_addr = tokens[0]
        # Remove angle brackets and colon from the second token to get the function name.
        func_name = tokens[1].strip("<>:")
        # Remove '@plt' from the function name if present
        if "@plt" in func_name:
            func_name = func_name.replace("@plt", "")
        func_map[func_name] = hex_addr

# --- Step 1.2: Process merged.json and build the output array ---

merged_json_path = sys.argv[1]
with open(merged_json_path, "r") as f:
    merged_entries = json.load(f)

# The result array will hold tuples (ID, address_int)
result = []

not_found_icall = []
not_found_target = []

for icall in merged_entries:
    icall_line = icall.get("line")
    # Look up the line in line_log_map; if not found, skip this icall.
    if icall_line not in line_log_map:
        not_found_icall.append(icall_line)
        continue
    # Use all IDs from the line_log mapping
    line_ids = line_log_map[icall_line]  # list of ints

    targets = icall.get("targets", [])
    # For each target function name, look up the address from func_map.
    for target in targets:
        # Remove trailing ".number" if present, e.g., "ngx_error_log.89" becomes "ngx_error_log"
        #clean_target = re.sub(r'\.\d+$', '', target)
        clean_target = target
        if clean_target in func_map:
            # Convert the hex address to an integer and fan-out to all line IDs.
            addr_int = int(func_map[clean_target], 16)
            for line_id in line_ids:
                result.append((line_id, addr_int))
        else:
            # If the function name is not found, track it.
            not_found_target.append(clean_target)
# --- Step 1.3: Output the result ---
# For example, print the array of (ID, address) pairs.
# print(result)
print("icall not found in current version:",len(not_found_icall), "[It's OK]")
# for icall in not_found_icall:
#     print(icall)
print("target not found in current version:",len(not_found_target), "[It's OK]")
deduplicated = list(dict.fromkeys(not_found_target))
print("after deduplication:",len(deduplicated), "[It's OK]\n")
# for target in deduplicated:
#     print(target)

# --- Step 1.4: Output the result ---
# 1. Write a text file "subgt_address_log_readable" with each line as "id address"
# 2. Write a binary file "address_log" where each pair is two uint64_t values.
with open("./subgt_address_log_readable", "w") as text_file, open("./subgt_address_log", "wb") as bin_file:
    for id_val, addr_val in result:
        # Write the text line
        text_file.write(f"{id_val} {addr_val}\n")
        # Write the binary data (two 64-bit unsigned integers)
        data = struct.pack("QQ", id_val, addr_val)
        bin_file.write(data)

print("Output written to subgt_address_log_readable (text) and subgt_address_log (binary).")

# --- Step 2: Move subgt_address_log to the target directory ---
print("\n[Step 2] Moving subgt_address_log to the target directory...")

# Ensure the directory log/subgt-extract exists
target_dir = os.path.join("log", "subgt-extract")
os.makedirs(target_dir, exist_ok=True)

# Copy ./subgt_address_log to log/subgt-extract/
src_file = "./subgt_address_log"
dst_file = os.path.join(target_dir, "subgt_address_log")
shutil.copy(src_file, dst_file)
print(f"Copied {src_file} to {dst_file}")
