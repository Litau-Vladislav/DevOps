# Quotes Scraper

A Python scraper using Playwright and Chromium. It opens
https://quotes.toscrape.com/scroll, collects dynamically loaded quotes,
authors and tags, and writes them to `out/result.json`.

## Local development

Requirements:
- Python 3.11 or newer
- uv
- Make
- Docker Engine with BuildKit support

Install Python dependencies:

```bash
uv sync --locked