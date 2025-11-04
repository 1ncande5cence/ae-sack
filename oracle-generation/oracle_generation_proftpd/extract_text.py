import os
from bs4 import BeautifulSoup
import re

INPUT_DIR = "./downloaded_docs"
OUTPUT_DIR = "./downloaded_txt"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def extract_text_from_html(html):
    soup = BeautifulSoup(html, "html.parser")
    # Remove unwanted elements
    for tag in soup(["script", "style", "noscript", "header", "footer", "nav", "form"]):
        tag.decompose()
    # Get text, collapse whitespace
    text = soup.get_text(separator=" ", strip=True)
    return text

def process_all_html():
    for filename in os.listdir(INPUT_DIR):
        if filename.endswith(".html"):
            html_path = os.path.join(INPUT_DIR, filename)
            txt_path = os.path.join(OUTPUT_DIR, filename.rsplit(".", 1)[0] + ".txt")
            with open(html_path, "r", encoding="utf-8") as f:
                html = f.read()
            text = extract_text_from_html(html)
            with open(txt_path, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"✅ Extracted text: {txt_path}")

if __name__ == "__main__":
    process_all_html() 