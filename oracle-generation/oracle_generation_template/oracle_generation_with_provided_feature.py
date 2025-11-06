# python3 oracle_generation_with_provided_feature.py --feature-json feature_output/xxxx.json

import sys
import os
import json
import random
import argparse
from openai import OpenAI, RateLimitError, APITimeoutError, APIConnectionError
from tqdm import tqdm
from pydantic import BaseModel
from typing import List
import time
import datetime

#MODEL_NAME = "gpt-4.1-nano-2025-04-14"
#MODEL_NAME = "gpt-4.1-2025-04-14"
MODEL_NAME = "gpt-4.1-mini-2025-04-14"
TEMPERATURE = 0.0

# proxy 
proxy_config = [
    {
        "https://": os.getenv('HTTPS_POE_PROXY'),
        "http://": os.getenv('HTTP_POE_PROXY')
    }
]

# Repeat to merge
Repeat_Number = 1

class Feature(BaseModel):
    feature: str
    explain: str

# === CLI argument ===
def parse_args():
    parser = argparse.ArgumentParser(description="Oracle generation with feature lists")
    parser.add_argument(
        "--feature-json",
        required=False,
        default=None,
        help="Local path to the feature list JSON file."
    )
    return parser.parse_args()

# Reads the input JSON of features
def load_features(json_path: str) -> List[Feature]:
    with open(json_path, "r") as f:
        raw_data = json.load(f)
    return [Feature(**item) for item in raw_data]

def generate_prompt(doc):
    with open("oracle_generation_with_provided_feature_prompt.txt", "r") as f:
        prompt = f.read()
    prompt += "#@#@#@#@#@\n\n"
    prompt += doc
    prompt += "\n\n#@#@#@#@#@"
    return prompt

def extract_with_retry(prompt, user_prompt, result_file, max_retries=3):
    """Extract content with retry logic for API errors"""
    client = OpenAI(base_url="https://openrouter.ai/api/v1")
    
    for attempt in range(max_retries):
        try:
            print(f"Attempt {attempt + 1}/{max_retries}...", end='', flush=True)
            start_time = time.time()
            response = client.beta.chat.completions.parse(
                model=MODEL_NAME,
                temperature=TEMPERATURE,
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": user_prompt}
                ],
                timeout=120
            )

            print(response.choices[0].message.content, file=result_file, end='', flush=True)
            print(" ✅")

            end_time = time.time()
            response_time = end_time - start_time
            return True, response_time
            
        except RateLimitError:
            wait_time = 60 + random.randint(0, 30)
            print(f" ⚠️ Rate limit hit, waiting {wait_time}s")
            time.sleep(wait_time)
            
        except (APITimeoutError, APIConnectionError):
            wait_time = 30 + random.randint(0, 20)
            print(f" ⚠️ Connection/timeout error, waiting {wait_time}s")
            time.sleep(wait_time)
            
        except KeyboardInterrupt:
            print(" ⏹️ Interrupted by user")
            raise
            
        except Exception as e:
            print(f" ❌ Unexpected error: {str(e)}")
            if attempt < max_retries - 1:
                wait_time = 10 + random.randint(0, 10)
                print(f"   Waiting {wait_time}s before retry...")
                time.sleep(wait_time)
            else:
                print(f"   All {max_retries} attempts failed")
                raise e
    
    return False, None

def create_directory_if_not_exists(directory_path):
    if not os.path.exists(directory_path):
        os.makedirs(directory_path)
        print(f"Directory created: {directory_path}")
    else:
        print(f"Directory already exists: {directory_path}")

# === MAIN ===
if __name__ == "__main__":
    args = parse_args()

    # Require user to provide feature list
    if args.feature_json is None:
        print("\n❌ ERROR: No feature list provided (--feature-json missing)\n")

        feature_dir = "./feature_output"
        print("📁 Available JSON files in feature_output/:")
        if not os.path.exists(feature_dir):
            print("   (Folder does not exist)")
        else:
            files = [f for f in os.listdir(feature_dir) if f.endswith(".json")]
            if not files:
                print("   (No .json files found)")
            else:
                for f in files:
                    print(f"   - {f}")

        print("\n✅ Example usage:")
        print("   python3 oracle_generation_with_provided_feature.py --feature-json feature_output/XXXX.json\n")
        sys.exit(1)

    feature_path = args.feature_json
    print(f"📁 Using feature list: {feature_path}")
    feature_list = load_features(feature_path)

    # DIRECTORIES
    input_dir = "./security_txt/"
    output_dir = "./oracle_generation_with_provided_feature/"
    create_directory_if_not_exists(output_dir)

    txt_files = [f for f in os.listdir(input_dir)]
    print(f"Found {len(txt_files)} files to combine")

    # Combine docs
    all_docs = []
    for filename in txt_files:
        file_path = os.path.join(input_dir, filename)
        with open(file_path, "r") as file:
            all_docs.append(file.read())

    combined_doc = "\n\n".join(all_docs)
    prompt = generate_prompt(combined_doc)

    oracle_id = 0

    for i, feat in enumerate(feature_list):
        oracle_id += 1
        print(f"[{i+1}/{len(feature_list)}] Processing: {feat.feature}")

        user_prompt = f"Feature: {feat.feature}\nExplanation: {feat.explain}"
        sanitized_feature_name = feat.feature.replace(' ', '_').replace('/', '_').replace('\\', '_')

        current_time = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file_name = os.path.join(output_dir, f"{oracle_id}_{sanitized_feature_name}_{current_time}.md")

        start_time = time.time()
        with open(result_file_name, "w") as result_file:
            result_file.write("**Response Time:** Calculating...\n\n")
            
            success, response_time = extract_with_retry(prompt, user_prompt, result_file, 3)
            
            # Update response time at file top
            result_file.seek(0)
            result_file.write(f"**Response Time:** {response_time:.2f} seconds\n\n")

        if success:
            print(f"✅ Completed feature: {feat.feature}")
        else:
            print(f"❌ Failed feature: {feat.feature}")

    print("🎉 All features processed!")
