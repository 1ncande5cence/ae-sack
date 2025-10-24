def find_missing_identifiers(first_file, second_file, output_file):
    # Read first file and extract full identifiers
    with open(first_file, 'r') as file1:
        first_file_ids = {line.split()[0] for line in file1}

    # Read second file and extract full identifiers
    second_file_ids = set()
    with open(second_file, 'r', errors='ignore') as f:
        for line in f:
            tokens = line.strip().split()
            if not tokens:
                continue
            first_word = tokens[0]
            if "_" in first_word:
                second_file_ids.add(first_word)  # now keep full ID

    # Find identifiers that exist in the first file but not in the second
    missing_ids = first_file_ids - second_file_ids

    # Write missing identifiers to the output file
    with open(output_file, 'w') as output:
        for identifier in sorted(missing_ids):
            output.write(identifier + '\n')

    print(f"Missing identifiers written to {output_file}")

# Example usage
first_file_path = "./log/probe_sudo_log"
second_file_path = "./sudo.log"
output_file_path = "missing_identifiers.txt"
find_missing_identifiers(first_file_path, second_file_path, output_file_path)
