**Response Time:** 17.11 seconds


Let's evaluate whether a security oracle can be generated for the "Anonymous Access Restrictions" feature in ProFTPD.

**Assessment:**  
The provided documentation contains detailed information about configuring anonymous access in ProFTPD, including how to enable/disable it, restrict directories, and control permissions. There are clear configuration directives and testable behaviors. Therefore, a security oracle **can** be generated.

---

# Security Oracle: Anonymous Access Restrictions in ProFTPD

## 1. Security Feature:  
**Anonymous Access Restrictions**  
ProFTPD allows administrators to control anonymous FTP access. This includes enabling or disabling anonymous logins, restricting which directories anonymous users can access, and setting fine-grained permissions (such as upload/download, directory listing, and file deletion) for anonymous users. This feature is critical for preventing unauthorized access or abuse of the FTP server.

---

## 2. Configuration Setup

### 2.1 Compilation Steps

**Description:**  
Ensure ProFTPD is installed. No special compilation flags are required for basic anonymous access control, as this is core functionality.

**Command:**
```sh
# On most systems, install via package manager or from source:
sudo apt-get install proftpd
# or, to build from source:
./configure
make
sudo make install
```

---

### 2.2 Configuration File

**Description:**  
Configure ProFTPD to restrict anonymous access. The following example disables anonymous uploads and restricts anonymous users to a specific directory.

**Snippet for `/etc/proftpd/proftpd.conf`:**
```apache
# Disable anonymous access entirely
# <Anonymous ~ftp>
#   User ftp
#   Group nogroup
#   <Limit LOGIN>
#     DenyAll
#   </Limit>
# </Anonymous>

# OR: Allow anonymous access, but restrict actions
<Anonymous /srv/ftp>
  User ftp
  Group nogroup

  # Deny uploads, deletes, and renames
  <Limit WRITE>
    DenyAll
  </Limit>

  # Allow downloads and directory listing
  <Limit READ>
    AllowAll
  </Limit>

  # Optionally, restrict login to certain IPs or times
  # <Limit LOGIN>
  #   Allow from 192.0.2.0/24
  #   DenyAll
  # </Limit>
</Anonymous>
```
**Explanation:**  
- The first block (commented out) shows how to disable anonymous access.
- The second block allows anonymous access but restricts uploads, deletes, and renames, while allowing downloads and directory listings.

---

### 2.3 Additional Setup Commands and Extra File

**Description:**  
Ensure the anonymous FTP directory exists and has correct permissions.

**Commands:**
```sh
# Create the FTP root directory for anonymous users
sudo mkdir -p /srv/ftp
sudo chown ftp:nogroup /srv/ftp
sudo chmod 755 /srv/ftp

# Restart ProFTPD to apply changes
sudo systemctl restart proftpd
```

---

## 3. Testing Instructions

### 3.1 Allowed Behavior: Anonymous Download

**Input:**  
Connect to the FTP server as "anonymous" and attempt to download a file.

**Command:**
```sh
ftp localhost
# At the prompt, enter "anonymous" as the username and any email as the password.
ftp> ls
ftp> get somefile.txt
```

**Expected Outcome:**  
- Directory listing is shown.
- File `somefile.txt` is downloaded successfully.
- FTP response code: `226 Transfer complete.`

---

### 3.2 Blocked Behavior: Anonymous Upload

**Input:**  
Connect as "anonymous" and attempt to upload a file.

**Command:**
```sh
ftp localhost
# Login as above
ftp> put testupload.txt
```

**Expected Outcome:**  
- Upload is denied.
- FTP response code: `550 Permission denied.` or similar error message.

---

### 3.3 Feature Functionality Determination

**Logic:**  
- If anonymous users can list and download files but cannot upload, delete, or rename files, the restriction is enforced.
- If anonymous login is disabled (using the first config block), any attempt to login as "anonymous" should be denied with a `530 Login incorrect.` message.

**Conclusion:**  
If the observed outcomes match the expected results above, the Anonymous Access Restrictions feature is functioning as intended.

---

**Summary:**  
This security oracle demonstrates how to configure, test, and verify enforcement of anonymous access restrictions in ProFTPD, ensuring that only permitted actions are allowed for anonymous users.