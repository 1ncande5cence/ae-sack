import time
from ftplib import FTP

def ftp_connect(host: str, username: str, password: str) -> FTP:
    """Establish an FTP connection."""
    ftp = FTP()
    try:
        ftp.connect(host, 21)
        print("Connected to FTP server")
        try:
            ftp.login(username, password)
            print("Login successful")
        except Exception as login_error:
            print(f"Login failed: {login_error}")
        return ftp
    except Exception as e:
        print(f"FTP Connection failed: {e}")
        return None

def list_files(ftp: FTP, path: str = ".") -> list:
    """List files in the specified directory."""
    files = []
    try:
        ftp.retrlines(f"LIST {path}", files.append)
        # ftp.retrlines(f"LIST /")
    except Exception as e:
        print(f"Error listing files: {e}")
    return files

def main():
    """Main function to handle FTP operations."""
    start_time = time.time()
    retry_interval = 0.5  # Time to wait before retrying
    max_duration = 200000#86400  # Maximum script run time in seconds
    
    ftp = None
    counter = 0
    while True:
        ftp = None
        counter +=1
        print("Count:",counter)
        #if time.time() - start_time > max_duration:
        #    print("Maximum duration reached. Exiting.")
        #    break
        
        if not ftp:
            try:
                #ftp = ftp_connect("127.0.0.1", "test", "test") # subgt
                ftp = ftp_connect("127.0.0.1", "test", "wrong") # oracle
                # ftp = ftp_connect("127.0.0.1", "", "") # new oracle
                if not ftp:
                    raise ConnectionError("FTP connection failed (no socket).")
            except Exception as e:
                print(f"Connection error: {e}")
                time.sleep(retry_interval)
                continue
        
        try:
            files = list_files(ftp)
            print("Files:", files)
        except Exception as e:
            print(f"File listing error: {e}")
            time.sleep(retry_interval)
            continue
        
        try:
            ftp.quit()
            ftp = None  # Reset FTP object to force reconnection in the next loop
        except Exception as e:
            print(f"Error quitting FTP session: {e}")
            time.sleep(retry_interval)
        
        print("Finished iteration.")
        print("----------------")
        time.sleep(retry_interval)

if __name__ == "__main__":
    main()
