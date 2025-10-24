import time
from ftplib import FTP, error_perm

def ftp_connect(host: str, username: str, password: str) -> FTP:
    """Attempt an FTP connection. Return FTP object even if login fails."""
    ftp = FTP()
    try:
        ftp.connect(host, 21)
        print("Connected to FTP server")
        ftp.login(username, password)  # This may fail, but we proceed
    except Exception as e:
        print(f"FTP login failed: {e}")
    return ftp  # Return FTP object even if login fails

def list_files(ftp: FTP, path: str = ".") -> list:
    """Attempt to list files, even if login failed."""
    files = []
    try:
        #response = ftp.sendcmd(f"LIST {path}")  # Send LIST command manually
        ftp.retrlines(f"LIST {path}", files.append)
        #print(response)  # Print raw response (like FTP command line)
    except error_perm as e:
        # This will catch "530 Please login" but still mimic FTP behavior
        print(f"Permission error (expected if not logged in): {e}")
    except Exception as e:
        print(f"Error listing files: {e}")
    return files

def main():
    """Main function to handle FTP operations."""
    start_time = time.time()
    retry_interval = 0.5  # Time to wait before retrying
    max_duration = 500000  # Maximum script run time in seconds
    
    counter = 0
    while True:
        counter += 1
        print("Count:", counter)
        
        if time.time() - start_time > max_duration:
            print("Maximum duration reached. Exiting.")
            break
        
        # Connect to FTP (login might fail, but we still proceed)
        ftp = ftp_connect("127.0.0.1", "test", "wrong")

        # Always attempt to list files, even if authentication failed
        try:


            files = list_files(ftp)  # `list_files` handles unauthenticated state gracefully
            print("Files:", files)
        except Exception as e:
            print(f"File listing error: {e}")

        # Always try to quit, even if login failed
        try:
            ftp.quit()
        except Exception as e:
            print(f"Error quitting FTP session (expected if not logged in): {e}")

        print("Finished iteration.")
        print("----------------")
        time.sleep(retry_interval)
        

if __name__ == "__main__":
    main()