import requests
from requests.auth import HTTPBasicAuth
import time
from datetime import datetime

# url = "http://localhost/index.html?param=abc" # subgt
url = "http://localhost/index.html?param=<script>alert('XSS')</script>" # oracle

output_file = "response_log.txt"

while True:
    try:
        response = requests.get(url)
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(output_file, "a") as f:
            f.write(f"[{timestamp}] Status Code: {response.status_code}\n")
            f.write(response.text + "\n\n")
        
        print(f"[{timestamp}] Request successful. Status Code: {response.status_code}")
        
    except requests.ConnectionError as e:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Connection failed. Retrying...")
    
    time.sleep(0.1)


