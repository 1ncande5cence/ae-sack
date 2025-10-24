#!/usr/bin/env python3
"""
Script to extract code from flip success logs.
Parses flip.success.log entries and finds corresponding source code locations.
"""

import os
import sys
import re
from pathlib import Path

def parse_flip_success_log(log_file):
    """Parse flip.success.log and return list of flip entries."""
    flips = []
    try:
        with open(log_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    # Format: id_enterCount_fromValue_toValue
                    parts = line.split('_')
                    if len(parts) == 3:
                        flip_entry = {
                            'id': int(parts[1]),
                            'enter_count': int(parts[2]),
                        }
                        flips.append(flip_entry)
    except FileNotFoundError:
        print(f"Error: Could not find {log_file}")
        return []
    return flips

def parse_branch_line_log(log_file):
    """Parse branch_line_log and return dictionary mapping id to file:line."""
    branches = {}
    try:
        with open(log_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    # Format: id file:line
                    parts = line.split(' ', 1)
                    if len(parts) == 2:
                        branch_id = int(parts[0])
                        file_line = parts[1]
                        branches[branch_id] = file_line
    except FileNotFoundError:
        print(f"Error: Could not find {log_file}")
        return {}
    return branches

def extract_code_from_file(file_path, line_number, context_lines=5):
    """Extract code around the specified line number with context."""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()

        # Convert to 0-based indexing
        line_idx = line_number - 1
        start_idx = max(0, line_idx - context_lines)
        end_idx = min(len(lines), line_idx + context_lines + 1)

        code_snippet = []
        for i in range(start_idx, end_idx):
            marker = ">>> " if i == line_idx else "    "
            code_snippet.append(f"{marker}{i+1:4d}: {lines[i].rstrip()}")

        return '\n'.join(code_snippet)
    except FileNotFoundError:
        return f"Error: Could not find source file {file_path}"
    except Exception as e:
        return f"Error reading file {file_path}: {e}"

def find_source_file(file_path, nginx_root_dir):
    """Find the actual source file in the nginx directory."""
    # Try different possible locations
    possible_paths = [
        os.path.join(nginx_root_dir, file_path),
        os.path.join(nginx_root_dir, 'src', file_path),
        os.path.join(nginx_root_dir, '..', 'src', file_path),
        os.path.join(nginx_root_dir, '..', '..', 'src', file_path),
    ]

    for path in possible_paths:
        if os.path.exists(path):
            return path

    return None

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 flip_code_extractor.py <flip_success_log> <branch_line_log> [nginx_root_dir]")
        print("Example: python3 flip_code_extractor.py flip.success.log branch_line_log /path/to/nginx")
        sys.exit(1)

    flip_log_file = sys.argv[1]
    branch_log_file = sys.argv[2]
    nginx_root_dir = sys.argv[3] if len(sys.argv) > 3 else "."

    print("=== Flip Code Extractor ===\n")

    # Parse logs
    print("Parsing flip success log...")
    flips = parse_flip_success_log(flip_log_file)
    print(f"Found {len(flips)} flip entries\n")

    print("Parsing branch line log...")
    branches = parse_branch_line_log(branch_log_file)
    print(f"Found {len(branches)} branch entries\n")

    # Process each flip entry
    for i, flip in enumerate(flips, 1):
        print(f"=== Flip Entry {i} ===")
        print(f"ID: {flip['id']}")
        print(f"Enter Count: {flip['enter_count']}")

        # Find corresponding branch
        if flip['id'] in branches:
            file_line = branches[flip['id']]
            print(f"Location: {file_line}")

            # Parse file:line
            if ':' in file_line:
                file_path, line_num = file_line.rsplit(':', 1)
                line_num = int(line_num)

                # Find actual source file
                actual_file = find_source_file(file_path, nginx_root_dir)
                if actual_file:
                    print(f"Source file: {actual_file}")
                    print("\nCode context:")
                    code = extract_code_from_file(actual_file, line_num)
                    print(code)
                else:
                    print(f"Could not find source file: {file_path}")
                    print("Tried paths:")
                    possible_paths = [
                        os.path.join(nginx_root_dir, file_path),
                        os.path.join(nginx_root_dir, 'src', file_path),
                        os.path.join(nginx_root_dir, '..', 'src', file_path),
                        os.path.join(nginx_root_dir, '..', '..', 'src', file_path),
                    ]
                    for path in possible_paths:
                        print(f"  - {path}")
            else:
                print(f"Invalid file:line format: {file_line}")
        else:
            print(f"Branch ID {flip['id']} not found in branch line log")

        print("\n" + "="*50 + "\n")

if __name__ == "__main__":
    main()

# python3 flip_code_extractor.py flip.success.log branch_line_log /path/to/source

#python3 flip_code_extractor_proftpd.py success.log log/branch_line_log /methodology.new/proftpd-collection/proftpd

# format of success.log                                                                                                                                        53,1          31%
# sack_2077_0
# sack_2048_0
# sack_2050_0
# sack_2051_0
# sack_2055_0