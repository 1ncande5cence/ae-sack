**Response Time:** 23.72 seconds


Let's evaluate whether a security oracle can be generated for the feature "Support for Two-Factor Authentication (via PAM or external modules)" in ProFTPD, based on the provided documentation.

**Assessment:**  
Yes, a security oracle can be generated. The documentation describes how ProFTPD can be integrated with PAM (Pluggable Authentication Modules) and external modules such as mod_auth_otp (for one-time passwords, e.g., TOTP/HOTP), and mod_sftp_pam (for SFTP keyboard-interactive authentication). These mechanisms can be configured to require a second factor (e.g., OTP code) in addition to the standard password, thus enforcing two-factor authentication (2FA).

---

## 1. Security Feature

**Name:**  
Two-Factor Authentication (2FA) via PAM or External Modules

**Description:**  
ProFTPD can be configured to require users to authenticate using two factors, typically a password and a one-time code (OTP), by integrating with PAM or external modules such as mod_auth_otp. This enhances login security by requiring something the user knows (password) and something the user has (OTP generator or app).

---

## 2. Configuration Setup

### 2.1 Compilation Steps

**Step 1: Compile ProFTPD with PAM and mod_auth_otp support**

- **Why:** To enable 2FA, ProFTPD must be compiled with PAM support (for general 2FA via PAM) and/or with mod_auth_otp for OTP-based 2FA.
- **Command:**
    ```sh
    # For PAM support (usually enabled by default on most systems)
    ./configure --with-modules=mod_auth_otp --enable-openssl
    make
    sudo make install
    ```

- **Optional:** If using SFTP and want 2FA for SFTP logins, also include mod_sftp and mod_sftp_pam:
    ```sh
    ./configure --with-modules=mod_sftp:mod_sftp_pam:mod_auth_otp --enable-openssl
    make
    sudo make install
    ```

### 2.2 Configuration File

**Step 2: Configure ProFTPD to use PAM and/or mod_auth_otp**

- **Why:** To enforce 2FA, ProFTPD must be told to use PAM and/or mod_auth_otp for authentication.

- **Snippet for PAM-based 2FA:**
    ```apache
    <IfModule mod_auth_pam.c>
      AuthPAM on
      AuthPAMConfig proftpd
    </IfModule>
    ```

    - Ensure your PAM stack for proftpd (e.g., `/etc/pam.d/proftpd`) is configured to require two factors, such as password + OTP (see below for PAM configuration).

- **Snippet for mod_auth_otp (TOTP/HOTP):**
    ```apache
    <IfModule mod_auth_otp.c>
      AuthOTPEngine on
      AuthOTPAlgorithm totp
      AuthOTPTable sql:/get-user-totp/update-user-totp
      # Optional: Require OTP for all users
      AuthOrder mod_auth_otp.c*
    </IfModule>
    ```

    - You must also configure mod_sql and the necessary SQLNamedQuery directives for OTP storage.

- **Example for SFTP with keyboard-interactive 2FA:**
    ```apache
    <IfModule mod_sftp.c>
      SFTPEngine on
      SFTPAuthMethods password keyboard-interactive
    </IfModule>
    <IfModule mod_sftp_pam.c>
      SFTPPAMEngine on
      SFTPPAMServiceName proftpd
    </IfModule>
    ```

### 2.3 Additional Setup Commands and Extra File

**Step 3: Configure PAM or OTP secrets**

- **Why:** The PAM stack or OTP secrets must be set up to require a second factor.

- **For PAM-based 2FA (e.g., using Google Authenticator):**
    1. Install the `libpam-google-authenticator` package.
    2. Edit `/etc/pam.d/proftpd` to include:
        ```
        auth required pam_google_authenticator.so
        auth required pam_unix.so
        ```
    3. Each user must run `google-authenticator` to set up their OTP secret.

- **For mod_auth_otp:**
    1. Create the SQL table for OTP secrets as described in the documentation.
    2. Populate the table with users' OTP secrets (base32-encoded).
    3. Example SQL schema:
        ```sql
        CREATE TABLE auth_otp (
            user TEXT PRIMARY KEY,
            secret TEXT,
            counter INTEGER
        );
        ```

---

## 3. Testing Instructions

### 3.1 Input that Satisfies the Feature (Allowed Behavior)

- **Test:** Attempt to log in as a user with both correct password and correct OTP code.
- **Expected Outcome:** Login is successful. For FTP, you see a "230 User logged in" message. For SFTP, the session is established.

### 3.2 Input that Violates the Feature (Should Be Blocked)

- **Test 1:** Attempt to log in with correct password but **no OTP code** (or an incorrect OTP code).
- **Expected Outcome:** Login is denied. For FTP, you see a "530 Login incorrect" or "Authentication failed" message. For SFTP, the client is prompted again or the session is closed.

- **Test 2:** Attempt to log in with correct OTP code but **incorrect password**.
- **Expected Outcome:** Login is denied. Same as above.

### 3.3 Determining Enforcement

- **If:**  
    - Only users who provide both correct password and correct OTP code can log in.
    - Users who provide only one factor (password or OTP) are denied access.
- **Then:**  
    - The two-factor authentication feature is functioning as expected and is enforced.

---

**Summary:**  
By following the above steps, you can configure and verify that ProFTPD enforces two-factor authentication using PAM or external modules. The enforcement is observable by the requirement for both password and OTP, and by the rejection of logins missing either factor.