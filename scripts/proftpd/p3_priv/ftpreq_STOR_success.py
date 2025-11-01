import time
from ftplib import FTP

def ftp_connect(host: str, username: str, password: str) -> FTP:
    """Establish an FTP connection."""
    ftp = FTP()
    try:
        ftp.connect(host, 21)
        print("Connected to FTP server")
        ftp.login(username, password)
        return ftp
    except Exception as e:
        print(f"FTP Connection failed: {e}")
        return None

def list_files(ftp: FTP, path: str = ".") -> list:
    """List files in the specified directory."""
    files = []
    try:
        ftp.retrlines(f"LIST {path}", files.append)
    except Exception as e:
        print(f"Error listing files: {e}")
    return files

def upload_file(ftp: FTP, local_path: str, remote_filename: str):
    """Upload a file using STOR command."""
    try:
        with open(local_path, 'rb') as f:
            ftp.storbinary(f'STOR {remote_filename}', f)
        print(f"Successfully uploaded '{local_path}' as '{remote_filename}'")
    except Exception as e:
        print(f"File upload failed: {e}")

def main():
    """Main function to handle FTP operations."""
    start_time = time.time()
    retry_interval = 0.5
    max_duration = 30000

    counter = 0
    while True:
        ftp = None
        counter += 1
        print("Count:", counter)

        # if time.time() - start_time > max_duration:
        #     print("Maximum duration reached. Exiting.")
        #     break

        try:
            ftp = ftp_connect("127.0.0.1", "valid", "valid")  # use correct creds if needed
            if not ftp:
                raise ConnectionError("FTP connection failed.")
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
            # Attempt to upload a dummy file
            with open("test_upload.txt", "w") as f:
                f.write("Hello FTP\n")
            upload_file(ftp, "test_upload.txt", "uploaded_test.txt")
        except Exception as e:
            print(f"Upload error: {e}")
            time.sleep(retry_interval)
            continue

        try:
            ftp.quit()
        except Exception as e:
            print(f"Error quitting FTP session: {e}")
        finally:
            ftp = None

        print("Finished iteration.")
        print("----------------")
        time.sleep(retry_interval)

if __name__ == "__main__":
    main()