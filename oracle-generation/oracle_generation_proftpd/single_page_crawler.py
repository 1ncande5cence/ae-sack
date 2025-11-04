import requests
from urllib.parse import urlparse
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Single-page crawler (no recursion).")
    parser.add_argument('--base-url', required=True, help='The URL of the page to download.')
    parser.add_argument('--output-dir', default='downloaded_docs', help='Directory to save the HTML file.')
    return parser.parse_args()

def save_page(url, html, output_dir):
    parsed = urlparse(url)
    rel_path = parsed.path.lstrip("/")
    name = rel_path.rstrip("/") or "index"
    name = name.replace("/", "_").replace(".", "_")
    filename = os.path.join(output_dir, f"{name}.html")
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"✅ Saved {url} -> {filename}")

def crawl_single_page(base_url, output_dir):
    try:
        response = requests.get(base_url)
        response.raise_for_status()
        save_page(base_url, response.text, output_dir)
    except Exception as e:
        print(f"❌ Failed to fetch base page: {e}")

if __name__ == "__main__":
    args = parse_args()
    crawl_single_page(args.base_url, args.output_dir)

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudo.conf.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudo.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudo_plugin.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudo_plugin_python.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudoers.ldap.man/   

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudoers.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/sudoers_timestamp.man/

# python3 single_page_crawler.py --base-url https://www.sudo.ws/docs/man/visudo.man/