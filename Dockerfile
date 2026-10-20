# syntax=docker/dockerfile:1.7

ARG PLAYWRIGHT_VERSION=1.64.0

# --------------------------------------------------
# Stage 1: Базовое окружение + Системные зависимости
# --------------------------------------------------
FROM node:22-bookworm AS base

ARG PLAYWRIGHT_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

# 1. Устанавливаем Python, curl и очищаем кэш
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# 2. Устанавливаем uv через официальный скрипт (обход проблем с ghcr.io)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# 3. Устанавливаем системные библиотеки для Chromium.
# Это ДОЛЖНО быть в base, чтобы они попали в финальный образ runtime!
RUN uvx --from "playwright==${PLAYWRIGHT_VERSION}" playwright install-deps chromium

# --------------------------------------------------
# Stage 2: Только скачивание бинарного файла браузера
# --------------------------------------------------
# Наследуется от base (где уже есть системные библиотеки)
FROM base AS browser

ARG PLAYWRIGHT_VERSION

# Скачиваем сам браузер. Эта стадия кешируется отдельно от Python-зависимостей.
RUN uvx --from "playwright==${PLAYWRIGHT_VERSION}" playwright install chromium

# --------------------------------------------------
# Stage 3: Только Python-зависимости
# --------------------------------------------------
# Наследуется от base. Строится параллельно со стадией browser.
FROM base AS deps

ENV UV_LINK_MODE=copy

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-dev

# --------------------------------------------------
# Stage 4: Финальный образ (runtime)
# --------------------------------------------------
# Наследуется от base (имеет Python + системные библиотеки для Chromium)
FROM base AS runtime

ENV PATH="/app/.venv/bin:${PATH}"

# Забираем скачанный браузер из стадии browser
COPY --from=browser /ms-playwright /ms-playwright

# Забираем готовое Python-окружение из стадии deps
COPY --from=deps /app/.venv /app/.venv

# Код копируем последним для максимального кеширования
COPY src/ ./src/

CMD ["/app/.venv/bin/python", "-u", "src/scraper.py"]