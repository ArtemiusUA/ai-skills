#!/usr/bin/env bash
set -euo pipefail

USAGE="Usage: $0 <project-dir> <package-name>

Scaffold a FastAPI project following the fastapi-project skill conventions.

Args:
  project-dir    Directory to create the project in (will be created if missing)
  package-name   Python package name (e.g. my_api, src, app)

Example:
  $0 ./my-project my_api
"

if [[ $# -lt 2 ]]; then
  echo "$USAGE"
  exit 1
fi

PROJECT_DIR="$1"
PACKAGE_NAME="$2"

if [[ ! "$PACKAGE_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "Error: package-name must be a valid Python identifier (snake_case, starts with a letter)."
  exit 1
fi

echo "==> Scaffolding FastAPI project in $PROJECT_DIR (package: $PACKAGE_NAME)"

mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PACKAGE_DIR="$PROJECT_DIR/$PACKAGE_NAME"
TESTS_DIR="$PROJECT_DIR/tests"

mkdir -p "$PACKAGE_DIR/api/routers"
mkdir -p "$PACKAGE_DIR/models"
mkdir -p "$PACKAGE_DIR/schemas"
mkdir -p "$PACKAGE_DIR/repositories"
mkdir -p "$PACKAGE_DIR/services"
mkdir -p "$TESTS_DIR/api/routers"
mkdir -p "$TESTS_DIR/factories"
mkdir -p "$TESTS_DIR/repositories"
mkdir -p "$TESTS_DIR/services"

for dir in "$PACKAGE_DIR" "$PACKAGE_DIR/api" "$PACKAGE_DIR/api/routers" \
           "$PACKAGE_DIR/models" "$PACKAGE_DIR/schemas" \
           "$PACKAGE_DIR/repositories" "$PACKAGE_DIR/services" \
           "$TESTS_DIR" "$TESTS_DIR/api" "$TESTS_DIR/api/routers" \
           "$TESTS_DIR/factories" "$TESTS_DIR/repositories" "$TESTS_DIR/services"; do
  touch "$dir/__init__.py"
done

cat > "$PROJECT_DIR/pyproject.toml" <<PYPROJECT
[project]
name = "${PACKAGE_NAME//_/-}"
version = "0.1.0"
description = "FastAPI project"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "sqlalchemy[asyncio]>=2.0.36",
    "asyncpg>=0.30.0",
    "pydantic>=2.10.0",
    "pydantic-settings>=2.6.0",
]

[dependency-groups]
dev = [
    "httpx>=0.28.1",
    "polyfactory>=3.3.0",
    "pytest>=9.1.1",
    "pytest-asyncio>=1.4.0",
    "ruff>=0.11.0",
    "mypy>=1.15.0",
]

[tool.ruff]
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B", "SIM", "ARG", "RUF"]
ignore = ["B008", "E731"]

[tool.ruff.lint.isort]
known-first-party = ["$PACKAGE_NAME"]

[tool.mypy]
python_version = "3.12"
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
PYPROJECT

cat > "$PROJECT_DIR/Makefile" <<MAKEFILE
.PHONY: dev_env lint lint-fix format format-check typecheck test check dev run

dev_env:
	uv sync --group dev
lint:
	uv run ruff check $PACKAGE_NAME/ tests/
lint-fix:
	uv run ruff check --fix $PACKAGE_NAME/ tests/
format:
	uv run ruff check --fix --select I $PACKAGE_NAME/ tests/ && uv run ruff format $PACKAGE_NAME/ tests/
format-check:
	uv run ruff format --check $PACKAGE_NAME/ tests/
typecheck:
	uv run mypy $PACKAGE_NAME/ tests/
test:
	uv run pytest
check: lint format-check typecheck
dev:
	uv run uvicorn $PACKAGE_NAME.api.main:app --reload
run:
	uv run uvicorn $PACKAGE_NAME.api.main:app
MAKEFILE

cat > "$PROJECT_DIR/.env.example" <<ENV
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/db
APP_TITLE=My API
APP_VERSION=0.1.0
LOG_LEVEL=INFO
CORS_ORIGINS=["*"]
ENV

cat > "$PROJECT_DIR/.gitignore" <<'GITIGNORE'
__pycache__/
*.py[cod]
*.egg-info/
.venv/
.env
*.sqlite3
dist/
build/
.ruff_cache/
.mypy_cache/
.pytest_cache/
GITIGNORE

cat > "$PROJECT_DIR/.editorconfig" <<'EDITORCONFIG'
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{yml,yaml,md}]
indent_size = 2
EDITORCONFIG

cat > "$PROJECT_DIR/Dockerfile" <<DOCKERFILE
FROM ghcr.io/astral-sh/uv:python3.12-alpine AS builder

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen

COPY . .

FROM python:3.12-alpine AS runtime

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/$PACKAGE_NAME /app/$PACKAGE_NAME

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "$PACKAGE_NAME.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKERFILE

cat > "$PACKAGE_DIR/__init__.py" <<'INIT'
INIT

cat > "$PACKAGE_DIR/config.py" <<CONFIG
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://user:pass@localhost:5432/db"
    app_title: str = "My API"
    app_version: str = "0.1.0"
    log_level: str = "INFO"
    cors_origins: list[str] = ["*"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
CONFIG

cat > "$PACKAGE_DIR/database.py" <<DATABASE
import logging

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from $PACKAGE_NAME.config import settings

logger = logging.getLogger(__name__)

engine = create_async_engine(settings.database_url, pool_pre_ping=True, echo=False)
async_session = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
DATABASE

cat > "$PACKAGE_DIR/exceptions.py" <<EXCEPTIONS
class NotFoundError(Exception):
    def __init__(self, detail: str = "Resource not found"):
        self.detail = detail


class BadRequestError(Exception):
    def __init__(self, detail: str = "Bad request"):
        self.detail = detail
EXCEPTIONS

cat > "$PACKAGE_DIR/logging_config.py" <<'LOGGING'
import logging
import sys


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        stream=sys.stdout,
    )
LOGGING

cat > "$PACKAGE_DIR/repositories/base.py" <<'BASE'
from abc import ABC, abstractmethod
from typing import Any, TypeVar

from sqlalchemy import func, inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")


class BaseRepository[T](ABC):
    @property
    @abstractmethod
    def model(self) -> type[T]: ...

    def __init__(self, session: AsyncSession):
        self.session = session

    async def add(self, **kwargs) -> T:
        obj = self.model(**kwargs)
        self.session.add(obj)
        await self.session.flush()
        await self.session.refresh(obj)
        return obj

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def get(self, pk: Any) -> T | None:
        return await self.session.get(self.model, pk)

    def _pk_column(self) -> Any:
        mapper = inspect(self.model)
        assert mapper is not None
        return mapper.primary_key[0]

    async def list(self, skip: int = 0, limit: int = 100, **filters) -> list[T]:
        order_col = self._pk_column()
        stmt = (
            select(self.model)
            .filter_by(**filters)
            .order_by(order_col)
            .offset(skip)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count(self, **filters) -> int:
        stmt = select(func.count()).select_from(self.model).filter_by(**filters)
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def update(self, pk: Any, **kwargs) -> T | None:
        obj = await self.get(pk)
        if obj is None:
            return None
        for key, value in kwargs.items():
            setattr(obj, key, value)
        await self.flush()
        await self.session.refresh(obj)
        return obj

    async def delete(self, pk: Any) -> bool:
        obj = await self.get(pk)
        if obj is None:
            return False
        await self.session.delete(obj)
        await self.flush()
        return True

    async def exists(self, **filters) -> bool:
        stmt = select(select(self.model).filter_by(**filters).exists())
        result = await self.session.execute(stmt)
        return result.scalar()
BASE

cat > "$PACKAGE_DIR/api/__init__.py" <<'INIT'
INIT

cat > "$PACKAGE_DIR/api/main.py" <<MAIN
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError

from $PACKAGE_NAME.api.routers import entities
from $PACKAGE_NAME.config import settings
from $PACKAGE_NAME.database import engine
from $PACKAGE_NAME.exceptions import BadRequestError, NotFoundError
from $PACKAGE_NAME.logging_config import configure_logging

logger = logging.getLogger(__name__)
configure_logging()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("Starting API")
    yield
    logger.info("Shutting down API")
    await engine.dispose()


app = FastAPI(title=settings.app_title, version=settings.app_version, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(IntegrityError)
async def integrity_error_handler(_request: Request, exc: IntegrityError):
    logger.warning("Integrity error: %s", exc)
    detail = str(exc.orig).split("\n")[0] if exc.orig else "Resource conflict"
    return JSONResponse(status_code=409, content={"detail": detail})


@app.exception_handler(NotFoundError)
async def not_found_handler(_request: Request, exc: NotFoundError):
    return JSONResponse(status_code=404, content={"detail": exc.detail})


@app.exception_handler(BadRequestError)
async def bad_request_handler(_request: Request, exc: BadRequestError):
    return JSONResponse(status_code=400, content={"detail": exc.detail})


@app.exception_handler(ValueError)
async def value_error_handler(_request: Request, exc: ValueError):
    return JSONResponse(status_code=422, content={"detail": str(exc)})


@app.exception_handler(Exception)
async def unhandled_error_handler(_request: Request, exc: Exception):
    logger.exception("Unhandled error: %s", exc)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


app.include_router(entities.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
MAIN

cat > "$PACKAGE_DIR/api/deps.py" <<DEPS
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from $PACKAGE_NAME.database import get_db
from $PACKAGE_NAME.repositories.entities import EntityRepository
from $PACKAGE_NAME.services.entities import EntityService


def get_entity_service(db: AsyncSession = Depends(get_db)) -> EntityService:
    return EntityService(EntityRepository(db))
DEPS

cat > "$TESTS_DIR/conftest.py" <<'CONFTEST'
import os

os.environ["DATABASE_URL"] = "postgresql+asyncpg://test:test@localhost:5432/test_db"
CONFTEST

cat > "$TESTS_DIR/repositories/conftest.py" <<'CONFTEST_REPO'
import pytest_asyncio
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from $PACKAGE_NAME.config import settings
from $PACKAGE_NAME.database import Base


@pytest_asyncio.fixture
async def session():
    engine = create_async_engine(settings.database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async_session = async_sessionmaker(engine, expire_on_commit=False)
    async with async_session() as s:
        yield s
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()
CONFTEST_REPO

cat > "$TESTS_DIR/services/conftest.py" <<'CONFTEST_SVC'
from unittest.mock import AsyncMock

import pytest


@pytest.fixture
def mock_entity_repo():
    return AsyncMock()
CONFTEST_SVC

cat > "$TESTS_DIR/api/routers/conftest.py" <<'CONFTEST_API'
from unittest.mock import AsyncMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from $PACKAGE_NAME.api.deps import get_entity_service
from $PACKAGE_NAME.api.main import app as _app


@pytest.fixture
def mock_entity_service():
    return AsyncMock()


@pytest_asyncio.fixture
async def client(mock_entity_service):
    _app.dependency_overrides[get_entity_service] = lambda: mock_entity_service
    transport = ASGITransport(app=_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    _app.dependency_overrides.clear()
CONFTEST_API

cat > "$TESTS_DIR/factories/models.py" <<'FACTORIES'
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory
from sqlalchemy.orm import DeclarativeBase

from $PACKAGE_NAME.models.entities import Entity


def model_to_dict(model: DeclarativeBase) -> dict:
    return {
        c.name: getattr(model, c.name)
        for c in model.__table__.columns
        if c.identity is None
    }


class EntityFactory(SQLAlchemyFactory[Entity]):
    __model__ = Entity
    __set_relationships__ = False
FACTORIES

cat > "$PACKAGE_DIR/schemas/paginated.py" <<PAGINATED
from typing import Any, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class PaginatedResponse[T](BaseModel):
    items: list[T]
    total: int
    skip: int
    limit: int
    has_next: bool
PAGINATED

cat > "$PACKAGE_DIR/schemas/__init__.py" <<SCHEMAS_INIT
from .paginated import PaginatedResponse

__all__ = ["PaginatedResponse"]
SCHEMAS_INIT

cat > "$PACKAGE_DIR/api/routers/utils.py" <<UTILS
from typing import Any

from ${PACKAGE_NAME}.schemas import PaginatedResponse


def paginated(
    items: list[Any], total: int, skip: int, limit: int
) -> PaginatedResponse[Any]:
    return PaginatedResponse(
        items=items,
        total=total,
        skip=skip,
        limit=limit,
        has_next=(skip + limit < total),
    )
UTILS

echo "==> Done! Project scaffolded at $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  uv sync --group dev"
echo "  cp .env.example .env"
echo "  # Edit .env with your DB credentials"
echo ""
echo "To add a new entity module, run this from the project root:"
echo "  <skill-dir>/scripts/add-module.sh <entity-singular> <entity-plural>"
