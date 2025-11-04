import os
import json
import time
from datetime import datetime
from openai import OpenAI
from pydantic import BaseModel
from typing import List

# ========== Load TARGET_PROG from config file ==========
CONFIG_PATH = "./config.json"

if not os.path.exists(CONFIG_PATH):
    raise FileNotFoundError(f"Config file not found: {CONFIG_PATH}")

with open(CONFIG_PATH, "r") as cf:
    config = json.load(cf)

TARGET_PROG = config.get("TARGET_PROG")
if not TARGET_PROG:
    raise ValueError("TARGET_PROG missing in config.json")

# =======================================================

output_dir = "./feature_output"
MODEL_NAME = "gpt-4.1-2025-04-14"
TEMPERATURE = 0.0

SYS_PROMPT = f"""
you are an experienced developer who is highly familiar with 
the {TARGET_PROG}'s features.
"""

USER_PROMPT = f"""
Your goal is to list all the security features {TARGET_PROG} has.
A security feature refers to any mechanism or component 
designed to protect a program and its resources from 
unauthorized access, misuse or attack. 
Common security features include but are not limited to:
access control,
system command execution,
security plugins,
command execution control,
database protection,
input validation, 
encryption, 
logging, 
rate limiting.
For each security feature, output it with a brief explanation.
You should be as detailed as possible. 
Your goal is to list all the security features {TARGET_PROG} has, in the following JSON format:
{{
  "features": [
    {{
      "feature": "",
      "explain": ""
    }},
    ...
  ]
}}
"""

class Feature(BaseModel):
    feature: str
    explain: str

class OutputFormat(BaseModel):
    features: List[Feature]

client = OpenAI()

def generate_output(model, sys_prompt, user_prompt, temperature):
    start_time = time.time()
    response = client.beta.chat.completions.parse(
        model=model,
        temperature=temperature,
        messages=[
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": user_prompt}
        ],
        response_format=OutputFormat
    )
    end_time = time.time()
    print(f"Time taken: {end_time - start_time} seconds")
    return response.choices[0].message.parsed.features

def save_json(output: List[Feature], model):
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"{timestamp}-{model}.json"
    filepath = os.path.join(output_dir, filename)

    with open(filepath, "w") as f:
        json.dump([feat.model_dump() for feat in output], f, indent=4)

    print(f"Saved to {filepath}")

if __name__ == "__main__":
    result = generate_output(MODEL_NAME, SYS_PROMPT, USER_PROMPT, TEMPERATURE)
    save_json(result, MODEL_NAME)
