**Response Time:** 28.66 seconds


Let's evaluate whether a security oracle can be generated for the feature "HTTP Strict Transport Security (HSTS)" in NGINX, based on the provided documentation and my background knowledge.

### Assessment

The provided documentation does **not** mention a dedicated directive for HSTS (such as `add_header Strict-Transport-Security ...`) or a built-in HSTS feature. However, NGINX can send arbitrary headers using the [`add_header`](http://nginx.org/en/docs/http/ngx_http_headers_module.html#add_header) directive, as described in the documentation:

> The ngx_http_headers_module module allows adding the “Expires” and “Cache-Control” header fields, and arbitrary fields, to a response header.

Therefore, it is possible to enforce HSTS in NGINX by using the `add_header` directive to send the `Strict-Transport-Security` header. This is a well-established and supported method in NGINX.

---

# Security Oracle for HTTP Strict Transport Security (HSTS) in NGINX

## 1. Security Feature

**HTTP Strict Transport Security (HSTS)**

HSTS is a web security policy mechanism that helps protect websites against protocol downgrade attacks and cookie hijacking. When enabled, the server sends a `Strict-Transport-Security` header to instruct browsers to only interact with the site using HTTPS for a specified period.

## 2. Configuration Setup

### 2.1 Compilation Steps

No special compilation is required for HSTS support, as the `add_header` directive is part of the standard NGINX build.

### 2.2 Configuration File

**Purpose:**  
Add the `Strict-Transport-Security` header to all HTTPS responses, ensuring browsers enforce HTTPS for the specified duration.

**Configuration Snippet:**

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/cert.key;

    # Add HSTS header
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ... other configuration ...
}
```

**Explanation:**
- `add_header Strict-Transport-Security ... always;` ensures the header is sent for all response codes (not just 200, 204, etc.).
- `max-age=31536000` tells browsers to remember to use HTTPS for 1 year.
- `includeSubDomains` applies the policy to all subdomains.

### 2.3 Additional Setup Commands and Extra File

No extra files or commands are required for HSTS enforcement.

## 3. Testing Instructions

### 3.1 Input that Satisfies the Feature (Allowed Behavior)

**Test Input:**  
Make an HTTPS request to the server:

```sh
curl -k -I https://example.com/
```

**Expected Output:**  
The response headers should include:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### 3.2 Input that Violates the Feature (Should be Blocked)

**Test Input:**  
Make an HTTP (not HTTPS) request to the server:

```sh
curl -I http://example.com/
```

**Expected Output:**  
- The response **should not** include the `Strict-Transport-Security` header (per RFC, HSTS is only sent over HTTPS).
- If the server is configured to redirect HTTP to HTTPS (recommended), you should see a `301` or `302` redirect to the HTTPS URL.

Example:

```
HTTP/1.1 301 Moved Permanently
Location: https://example.com/
# No Strict-Transport-Security header present
```

### 3.3 Feature Functionality Determination

- If HTTPS responses **always** include the `Strict-Transport-Security` header with the correct value, and HTTP responses do **not** include it, the feature is functioning as expected.
- Browsers that have seen the HSTS header will refuse to connect to the site over HTTP, enforcing secure connections.

---

**Summary:**  
This oracle demonstrates that HSTS is enforced in NGINX by adding the appropriate header via the `add_header` directive, and provides concrete, testable steps to verify its enforcement.