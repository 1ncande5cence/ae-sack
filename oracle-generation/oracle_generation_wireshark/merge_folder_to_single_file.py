import os

input_dir = "./security_txt"
output_file = "merged.txt"

# Get all files in the directory, sorted by filename
files = sorted([f for f in os.listdir(input_dir) if os.path.isfile(os.path.join(input_dir, f))])

with open(output_file, "w", encoding="utf-8") as outfile:
    for fname in files:
        file_path = os.path.join(input_dir, fname)
        with open(file_path, "r", encoding="utf-8") as infile:
            # Optional: Write a header for each file
            outfile.write(f"\n\n# ===== {fname} =====\n\n")
            outfile.write(infile.read())

print(f"All files in '{input_dir}' have been merged into '{output_file}'.")