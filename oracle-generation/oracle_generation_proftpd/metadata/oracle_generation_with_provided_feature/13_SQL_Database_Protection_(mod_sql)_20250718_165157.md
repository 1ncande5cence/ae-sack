**Response Time:** 25.08 seconds


Let's evaluate whether a security oracle can be generated for the feature "SQL Database Protection (mod_sql)" in ProFTPD, specifically focusing on secure connections to the database and restricting database access to authorized users.

**Assessment:**  
The provided documentation contains detailed information about configuring mod_sql, including how to set up secure (SSL/TLS) connections to the database and how to specify database user credentials. It also describes how to restrict access by using database users with limited privileges. Therefore, a security oracle can be generated.

---

# Security Oracle: SQL Database Protection (mod_sql)

## 1. Security Feature

**SQL Database Protection (mod_sql)**  
This feature ensures that ProFTPD, when using the mod_sql module for authentication or logging, connects to the backend SQL database using a secure (SSL/TLS) connection and restricts database access to only authorized users. This prevents unauthorized access to sensitive user data and credentials, and protects data in transit from eavesdropping or tampering.

---

## 2. Configuration Setup

### 2.1 Compilation Steps

**Step 1: Compile ProFTPD with mod_sql and SSL support**

- **Description:**  
  Ensure ProFTPD is compiled with both mod_sql (and the appropriate backend, e.g., mod_sql_mysql) and OpenSSL support, so that secure connections to the database are possible.

- **Command:**
  ```sh
  ./configure --with-modules=mod_sql:mod_sql_mysql --enable-openssl \
    --with-includes=/usr/local/mysql/include/mysql:/usr/local/openssl/include \
    --with-libraries=/usr/local/mysql/lib/mysql:/usr/local/openssl/lib
  make
  make install
  ```

### 2.2 Configuration File

**Step 2: Configure mod_sql to use a secure connection and restrict database access**

- **Description:**  
  Edit your `proftpd.conf` to:
  - Use a dedicated, least-privilege database user for ProFTPD.
  - Enable SSL/TLS for the SQL connection by specifying the CA, client certificate, and key.
  - Restrict mod_sql to use only the configured user and database.

- **Configuration Snippet:**
  ```apache
  <IfModule mod_sql.c>
    SQLEngine on
    SQLBackend mysql

    # Use a dedicated, least-privilege user (e.g., 'proftpd_user')
    SQLConnectInfo ftpdb@dbhost:3306 proftpd_user strongpassword \
      PERSESSION \
      ssl-ca:/etc/ssl/certs/mysql-ca.pem \
      ssl-cert:/etc/ssl/certs/proftpd-client-cert.pem \
      ssl-key:/etc/ssl/private/proftpd-client-key.pem

    # Example user info mapping
    SQLUserInfo users userid passwd uid gid homedir shell
    SQLGroupInfo groups groupname gid members
  </IfModule>
  ```

  - `ssl-ca`, `ssl-cert`, and `ssl-key` ensure the connection is encrypted and authenticated.
  - The database user `proftpd_user` should have only the minimum privileges required (e.g., SELECT for authentication, INSERT for logging).

### 2.3 Additional Setup Commands and Extra File

**Step 3: Create and Secure Database User and Certificates**

- **Description:**  
  - Create a dedicated database user with limited privileges.
  - Generate and install the necessary SSL certificates and keys.
  - Set file permissions to restrict access to the certificate and key files.

- **Commands:**
  ```sql
  -- In MySQL/MariaDB:
  CREATE USER 'proftpd_user'@'%' IDENTIFIED BY 'strongpassword' REQUIRE SSL;
  GRANT SELECT ON ftpdb.users TO 'proftpd_user'@'%';
  GRANT SELECT ON ftpdb.groups TO 'proftpd_user'@'%';
  -- Add other privileges as needed, but avoid unnecessary ones.
  FLUSH PRIVILEGES;
  ```

  ```sh
  # Generate CA, server, and client certificates as needed (example using OpenSSL)
  # Ensure /etc/ssl/private/proftpd-client-key.pem is readable only by root/proftpd
  chmod 600 /etc/ssl/private/proftpd-client-key.pem
  chown proftpd:proftpd /etc/ssl/private/proftpd-client-key.pem
  ```

---

## 3. Testing Instructions

### 3.1 Allowed Behavior: Secure, Authorized Access

- **Input:**  
  Start ProFTPD and attempt to authenticate as a valid FTP user. Ensure the database is reachable, the user exists, and the SSL/TLS connection is properly configured.

- **Observable Outcome:**  
  - ProFTPD logs show successful SSL/TLS connection to the database (check SQLLogFile and MySQL logs).
  - FTP login succeeds.
  - Database logs show connections from `proftpd_user` using SSL.
  - No plaintext credentials are visible on the network (verify with Wireshark/tcpdump).

### 3.2 Blocked Behavior: Insecure or Unauthorized Access

- **Input 1:**  
  Attempt to connect to the database from ProFTPD with SSL disabled or with an invalid certificate.

- **Observable Outcome:**  
  - ProFTPD fails to connect to the database.
  - Error in ProFTPD logs: "SSL connection error: SSL is required but the server doesn't support it" or similar.
  - FTP login fails with an authentication error.

- **Input 2:**  
  Attempt to connect to the database as a different, unauthorized user or from an unauthorized host.

- **Observable Outcome:**  
  - Database denies the connection.
  - ProFTPD logs show authentication/connection failure.
  - FTP login fails.

### 3.3 Feature Functionality Determination

- **If:**  
  - Only authorized users (with correct certificates and credentials) can connect to the database.
  - All database connections from ProFTPD are encrypted (verified via logs or packet capture).
  - Unauthorized or insecure connection attempts are blocked and logged.

- **Then:**  
  The SQL Database Protection feature is functioning as expected.

---

**Summary:**  
This security oracle demonstrates that ProFTPD's mod_sql can be configured to enforce secure, restricted database access by using SSL/TLS and least-privilege database users. The configuration and test steps above provide a concrete, testable method to verify enforcement of this security feature.