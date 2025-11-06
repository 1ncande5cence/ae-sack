# python3 doc_annotate.py $model "ardupilot_docs" $file

import sys
import os
import json
import random
from openai import OpenAI, RateLimitError, APITimeoutError, APIConnectionError
from tqdm import tqdm
import time
import datetime

#MODEL_NAME = "gpt-4.1-nano-2025-04-14"
MODEL_NAME = "gpt-4.1-2025-04-14"
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

def generate_prompt():
    prompt_file = open("single_query_prompt.txt", "r")
    prompt = prompt_file.read()
    prompt_file.close()
    return prompt

def extract_with_retry(prompt, result_file, max_retries=3):
    """Extract content with retry logic for API errors"""
    client = OpenAI(base_url="https://openrouter.ai/api/v1")
    
    for attempt in range(max_retries):
        try:
            print(f"�� Attempt {attempt + 1}/{max_retries}...", end='', flush=True)
            start_time = time.time()
            response = client.beta.chat.completions.parse(
                model=MODEL_NAME,
                temperature=TEMPERATURE,
                messages=[
                    {"role": "system", "content": prompt}
                ],
                timeout=120  # 2 minute timeout
            )

            print(response.choices[0].message.content, file=result_file, end='', flush=True)
            print(" ✅")  # Success indicator

            end_time = time.time()
            response_time = end_time - start_time
            return True, response_time  # Return success and time
            
        except RateLimitError as e:
            wait_time = 60 + random.randint(0, 30)  # Wait 60-90 seconds
            print(f" ⚠️ Rate limit hit, waiting {wait_time}s")
            time.sleep(wait_time)
            
        except (APITimeoutError, APIConnectionError) as e:
            wait_time = 30 + random.randint(0, 20)  # Wait 30-50 seconds
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
    
    return False, None  # All retries failed

def extract(prompt, result_file):
    """Legacy function for backward compatibility"""
    return extract_with_retry(prompt, result_file)

def create_directory_if_not_exists(directory_path):
    """
    Check if the directory at the specified path exists, and create it if it doesn't.

    :param directory_path: The path of the directory to check and create
    """
    if not os.path.exists(directory_path):
        try:
            os.makedirs(directory_path)
            print(f"Directory created: {directory_path}")
        except OSError as e:
            print(f"Error creating directory: {e}")
    else:
        print(f"Directory already exists: {directory_path}")

if __name__ == "__main__":
    # Debug mode: set to True to test with just one file
    DEBUG_MODE = False
    
    # Define directories (available for both debug and normal modes)
    # input_dir = "/crawler/result_annotate/"
    # output_dir = "./result_annotate_to_oracle/"
    # input_dir = "/crawler/3_security_module_docs_annotate/"
    output_dir = "./single_query/"
    
    # Create output directory if it doesn't exist
    create_directory_if_not_exists(output_dir)
    
    if DEBUG_MODE:
        # Debug: process just one file
        #test_filename = "ngx_http_auth_basic_module_summary.txt"  # Change this to test different files
        #file_path = os.path.join(input_dir, test_filename)
        #with open(file_path, "r") as file:
        #   doc = file.read()
        
        prompt = generate_prompt()
        
        # Create result filename for debug
        current_time = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        result_file_name = os.path.join(output_dir, f"single_query_{current_time}.md")
        
        # Process the document with retry logic
        with open(result_file_name, "w") as result_file:
                        # Write a placeholder for response time
            result_file.write("**Response Time:** Calculating...\n\n")
            # Get the current position after writing the placeholder
            time_header_end = result_file.tell()
            
            success, response_time = extract_with_retry(prompt, result_file, 3)
            
            # Go back and update the response time
            result_file.seek(0)
            result_file.write(f"**Response Time:** {response_time:.2f} seconds\n\n")

        
        print(f"🔧 DEBUG: Processed: {result_file_name}")
        
    else:
        # Process all files in the security_module_docs folder
        # Get all .txt files in the input directory
        print("Starting processing with retry logic and rate limit handling...")

        # Process files with progress bar
        try:
            # Read the document
            
            prompt = generate_prompt()
            
            # Create result filename: remove .txt extension and add _summary
            #result_file_name = os.path.join(output_dir, f"{base_name}_oracle.txt")
            current_time = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            result_file_name = os.path.join(output_dir, f"query_{current_time}.md")
            
            # Process the document with retry logic
            start_time = time.time()
            with open(result_file_name, "w") as result_file:
                # Write a placeholder for response time
                result_file.write("**Response Time:** Calculating...\n\n")
                # Get the current position after writing the placeholder
                time_header_end = result_file.tell()
                
                success, response_time = extract_with_retry(prompt, result_file, 3)
                
                # Go back and update the response time
                result_file.seek(0)
                result_file.write(f"**Response Time:** {response_time:.2f} seconds\n\n")

            if success:
                processing_time = time.time() - start_time
                print(f"✅  ({processing_time:.1f}s)")
            else:
                print(f"❌ Failed to process  after all retries")
            
            # Longer delay between files to avoid rate limiting
            delay = 3 + random.randint(0, 2)  # 3-5 seconds
            time.sleep(delay)
            
        except KeyboardInterrupt:
            print(f"\n⏹️ Interrupted while processing")
            print("You can resume by running the script again - it will skip already processed files")
            
        except Exception as e:
            print(f"❌ Error processing : {str(e)}")

        print("🎉 Processing complete!")