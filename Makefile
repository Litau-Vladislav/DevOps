IMAGE := quotes-scraper:latest

.PHONY: build run clean ci

# Build the production image using Docker BuildKit.
build:
	DOCKER_BUILDKIT=1 docker build -t "$(IMAGE)" .

# Build the image if needed, then run the scraper.
# The output directory is mounted from the host.
run: build
	mkdir -p out
	docker run --rm --init \
		--volume "$(CURDIR)/out:/out" \
		"$(IMAGE)"

# Remove the image and generated output.
# Keep Docker's build cache for future builds.
clean:
	@docker image rm -f "$(IMAGE)" >/dev/null 2>&1 || true
	rm -rf out

# Run the scraper and validate its JSON output.
ci: run
	python3 -c 'import json; from pathlib import Path; p = Path("out/result.json"); assert p.is_file() and p.stat().st_size > 0, "result.json is missing or empty"; data = json.loads(p.read_text(encoding="utf-8")); assert isinstance(data, list) and data, "JSON must contain a non-empty list"; required = {"text", "author", "tags"}; assert all(isinstance(item, dict) and required <= item.keys() for item in data), "Invalid quote structure"; print(f"Validated {len(data)} quotes")'

.PHONY: check-network

# Check HTTPS connectivity from inside the application container.
check-network: build
	docker run --rm --init \
		--entrypoint /app/.venv/bin/python \
		"$(IMAGE)" \
		-c 'import urllib.request; url = "https://quotes.toscrape.com/scroll"; response = urllib.request.urlopen(url, timeout=20); print("HTTP status:", response.status)'
