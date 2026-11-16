import json
import os
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

URL = "https://quotes.toscrape.com/scroll"
OUTPUT = Path(os.environ.get("OUTPUT_FILE", "/out/result.json"))


def scrape_quotes() -> list[dict]:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)

        try:
            page = browser.new_page()
            page.goto(URL, wait_until="domcontentloaded", timeout=60000)
            page.locator(".quote").first.wait_for(timeout=30000)

            previous_count = 0
            stable_rounds = 0

            for _ in range(60):
                page.evaluate(
                    "window.scrollTo(0, document.body.scrollHeight)"
                )
                page.wait_for_timeout(500)

                current_count = page.locator(".quote").count()

                if current_count == previous_count:
                    stable_rounds += 1
                else:
                    stable_rounds = 0

                if stable_rounds >= 4:
                    break

                previous_count = current_count

            quotes = []

            for item in page.locator(".quote").all():
                quotes.append(
                    {
                        "text": item.locator(".text").inner_text(),
                        "author": item.locator(".author").inner_text(),
                        "tags": item.locator(".tag").all_inner_texts(),
                    }
                )

            if not quotes:
                raise RuntimeError("No quotes were found on the page")

            return quotes

        finally:
            browser.close()


def main() -> None:
    quotes = scrape_quotes()

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(quotes, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Saved {len(quotes)} quotes to {OUTPUT}")


print("test")

if __name__ == "__main__":
    main()