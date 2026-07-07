# Project Setup & Tooling

## Package Management
- Use **uv** (`uv sync`, `uv run`, `uv add`).
- Declare project metadata and dependencies in `pyproject.toml` (not `setup.py`/`setup.cfg`).
- Python version: `>=3.12`.

## Key Dependencies
```toml
[project]
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "sqlalchemy[asyncio]>=2.0.36",
    "asyncpg>=0.30.0",
    "pydantic>=2.10.0",
    "pydantic-settings>=2.6.0",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.11.0",
    "mypy>=1.15.0",
]
```

Dev-only test deps go in `[dependency-groups]`:
```toml
[dependency-groups]
dev = [
    "httpx>=0.28.1",
    "polyfactory>=3.3.0",
    "pytest>=9.1.1",
    "pytest-asyncio>=1.4.0",
]
```

## Ruff Configuration
```toml
[tool.ruff]
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B", "SIM", "ARG", "RUF"]
ignore = ["B008", "E731"]

[tool.ruff.lint.isort]
known-first-party = ["<project_package>"]
```

## MyPy Configuration
```toml
[tool.mypy]
python_version = "3.12"
strict = true
ignore_missing_imports = true
```

## Pytest Configuration
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

## Makefile Targets
```makefile
.PHONY: dev_env lint lint-fix format format-check typecheck test check dev run

dev_env:    uv sync --group dev
lint:       uv run ruff check <package>/ tests/
lint-fix:   uv run ruff check --fix <package>/ tests/
format:     uv run ruff check --fix --select I <package>/ tests/ && uv run ruff format <package>/ tests/
format-check: uv run ruff format --check <package>/ tests/
typecheck:  uv run mypy <package>/ tests/
test:       uv run pytest
check:      lint format-check typecheck
dev:        uv run uvicorn <package>.api.main:app --reload
run:        uv run uvicorn <package>.api.main:app
```

## Environment Variables
Use `.env` / `.env.example` for configuration. Load via `pydantic-settings`.

## Coding Conventions

- **Type hints** everywhere.
- Use `from <package> import X` (known-first-party package name).
- `__init__.py` re-exports all public symbols via `__all__`.
- Variables: `snake_case`. Classes: `PascalCase`. Constants: `UPPER_SNAKE_CASE`.
- Use `logging.getLogger(__name__)` per module.
- `uv run <command>` for any tool execution.
