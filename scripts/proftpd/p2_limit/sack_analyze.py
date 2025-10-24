import os
import re
import sys

def extract_numbers(filename):
    match = re.search(r'sack_(\d+)_.*_(\d+)', filename)
    if match:
        return int(match.group(1)), int(match.group(2))
    return None

def process_files(directory):
    valid_files = []
    
    for filename in os.listdir(directory):
        # if filename.startswith("sack_112"):
        #     continue
        file_path = os.path.join(directory, filename)
        
        if os.path.isfile(file_path):
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                
                if content.count("Proftpd Safely Exit") == 3 and "mod_ban/0.8: Login denied: host '127.0.0.1' banned" not in content and "BEGIN STACK TRACE" not in content and "ProFTPD killed" not in content and content.count("FTP session opened") == 3 and content.count("USER test (Login failed): Incorrect password") == 3:
                    valid_files.append(filename)
    
    return sorted(valid_files, key=lambda x: extract_numbers(x) or (float('inf'), float('inf')))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 analyze_oracle.py <folder_path>")
        sys.exit(1)

    folder_path = sys.argv[1]
    
    matching_files = process_files(folder_path)
    
    #print("Files that meet the criteria:")
    for file in matching_files:
        print(file)
