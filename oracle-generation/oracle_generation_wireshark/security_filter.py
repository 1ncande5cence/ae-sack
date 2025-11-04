import os
import shutil
import re

# Default security keywords
SECURITY_KEYWORDS = [
    "authentication", "authorization", "protection","security", 
    "secure","log","password", "limit"
]

INPUT_DIR = "./downloaded_txt"
OUTPUT_DIR = "./security_txt"
THRESHOLD = 1  # Minimum number of different keywords to keep the file

os.makedirs(OUTPUT_DIR, exist_ok=True)

def filter_security_files():
    count_total = 0
    count_kept = 0
    count_discarded = 0
    for filename in os.listdir(INPUT_DIR):
        txt_path = os.path.join(INPUT_DIR, filename)
        with open(txt_path, "r", encoding="utf-8") as f:
            text = f.read()
        count_total += 1
        matched_keywords = [] # Will store tuples of (keyword, count)
        text_lower = text.lower()
        for kw in SECURITY_KEYWORDS:
            pattern = r'\b' + re.escape(kw) + r'\b'
            count = len(re.findall(pattern, text_lower))
            if count > 0:
                matched_keywords.append((kw, count))

        if matched_keywords:
            shutil.copy(txt_path, os.path.join(OUTPUT_DIR, filename))
            print(f"\n✅ Kept: {filename}")
            for kw, count in sorted(matched_keywords):
                print(f"   ➡️ - {kw}: {count} times")
            count_kept += 1
        else:
            print(f"\n❌ Discarded: {filename}")
            print(f"   No exact keyword match.")
            for kw, count in sorted(matched_keywords):
                print(f"   ➡️ - {kw}: {count} times")
            output_path = os.path.join(OUTPUT_DIR, filename)
            count_discarded += 1
            if os.path.exists(output_path):
                os.remove(output_path)

    print(f"\nTotal files: {count_total}")
    print(f"Kept files: {count_kept}")
    print(f"Discarded files: {count_discarded}")

if __name__ == "__main__":
    filter_security_files()