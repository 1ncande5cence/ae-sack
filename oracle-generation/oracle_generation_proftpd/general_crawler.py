import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import os
import argparse
import time
import json

CONFIG_PATH = "./config.json"

def load_config():
    if not os.path.exists(CONFIG_PATH):
        raise FileNotFoundError(f"Config file not found: {CONFIG_PATH}")
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)

def parse_args(config):
    parser = argparse.ArgumentParser(description="One-level web crawler for links on a single page.")

    parser.add_argument(
        '--base-url',
        help='The URL of the page to extract links from (overrides config file).'
    )

    parser.add_argument(
        '--output-dir',
        default='downloaded_docs',
        help='Directory to save downloaded HTML files.'
    )

    parser.add_argument(
        '--delay',
        type=float,
        default=0.5,
        help='Delay between requests (seconds).'
    )

    args = parser.parse_args()

    # If user does NOT pass --base-url, fallback to config.json
    if not args.base_url:
        if "START_URL" not in config:
            raise ValueError("START_URL missing in config.json")
        args.base_url = config["START_URL"]

    return args


def is_valid_url(url, domain):
    parsed = urlparse(url)
    return parsed.netloc == domain or parsed.netloc == ''


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


def crawl_single_page(base_url, output_dir, delay):
    domain = urlparse(base_url).netloc
    try:
        response = requests.get(base_url)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")

        links = set()
        for tag in soup.find_all("a", href=True):
            href = tag['href']
            full_url = urljoin(base_url, href)
            if is_valid_url(full_url, domain):
                links.add(full_url.split('#')[0])  # strip fragments

        print(f"🔗 Found {len(links)} unique links on the page.")

        for link in links:
            try:
                res = requests.get(link)
                if res.status_code == 200:
                    save_page(link, res.text, output_dir)
                    time.sleep(delay)
                else:
                    print(f"❌ Failed to fetch: {link}")
            except Exception as e:
                print(f"⚠️ Error fetching {link}: {e}")

    except Exception as e:
        print(f"❌ Failed to fetch base page: {e}")


if __name__ == "__main__":
    config = load_config()
    args = parse_args(config)
    crawl_single_page(args.base_url, args.output_dir, args.delay)
