import requests
from requests.auth import HTTPBasicAuth
import time
from datetime import datetime

url = "http://localhost/private/"

output_file = "response_log.txt"

while True:
    try:
        response = requests.get(url, auth=HTTPBasicAuth("song", "wrong")) # logging-oracle
        # response = requests.get(url, auth=HTTPBasicAuth("song", "secret")) # logging-subgt
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(output_file, "a") as f:
            f.write(f"[{timestamp}] Status Code: {response.status_code}\n")
            f.write(response.text + "\n\n")
        
        print(f"[{timestamp}] Request successful. Status Code: {response.status_code}")
        
    except Exception:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Connection failed. Retrying...")
    
    time.sleep(0.1)
    # break

