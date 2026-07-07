# Deployment

> **Note:** Database schema migrations are outside this skill's scope. Use any migration tool (Alembic, Sqitch, Liquibase, etc.) to manage your schema changes. The scaffolded project provides SQLAlchemy models as the source of truth.

## Dockerfile Pattern

```dockerfile
FROM ghcr.io/astral-sh/uv:python3.12-alpine AS builder

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen

COPY . .

FROM python:3.12-alpine AS runtime

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/<package> /app/<package>

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "<package>.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
