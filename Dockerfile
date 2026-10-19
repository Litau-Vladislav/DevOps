# syntax=docker/dockerfile:1.7

ARG PLAYWRIGHT_VERSION=1.64.0

# --------------------------------------------------
# Stage 1: системное окружение для Chromium
# --------------------------------------------------
FROM node:22-bookworm AS os-deps

ARG PLAYWRIGHT_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Устанавливаем Python и инструменты для создания venv.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Берём только исполняемые файлы uv из официального образа uv.
# Готовый образ Playwright не используется.
COPY --from=ghcr.io/astral-sh/uv:0.13.1 /uv /uvx /bin/

# Устанавливаем системные библиотеки, необходимые Chromium.
# uvx временно запускает Playwright нужной версии.
RUN uvx --from "playwright==${PLAYWRIGHT_VERSION}" \
        playwright install-deps chromium \
    && rm -f /bin/uv /bin/uvx \
    && rm -rf /root/.cache/uv /tmp/*

# --------------------------------------------------
# Stage 2: Python-зависимости и браузер
# --------------------------------------------------
FROM os-deps AS browser

# uv нужен на этапе сборки, но не в финальном образе.
COPY --from=ghcr.io/astral-sh/uv:0.13.1 /uv /uvx /bin/

ENV UV_LINK_MODE=copy

WORKDIR /app

# Сначала копируем только описание зависимостей.
COPY pyproject.toml uv.lock ./

# Устанавливаем зависимости из lock-файла.
# Кешируем загрузки пакетов между сборками.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-dev

# Устанавливаем Chromium отдельно от исходного кода.
RUN uv run --no-sync playwright install chromium

# --------------------------------------------------
# Stage 3: финальный образ приложения
# --------------------------------------------------
FROM os-deps AS runtime

WORKDIR /app

ENV PATH="/app/.venv/bin:${PATH}"

# Переносим только готовое Python-окружение и браузер.
COPY --from=browser /app/.venv /app/.venv
COPY --from=browser /ms-playwright /ms-playwright

# Код копируем последним, чтобы его изменения
# не инвалидировали слои установки зависимостей и браузера.
COPY src/ ./src/

CMD ["/app/.venv/bin/python", "-u", "src/scraper.py"]
