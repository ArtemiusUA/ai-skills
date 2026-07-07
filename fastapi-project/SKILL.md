---
name: fastapi-project
description: >
  Use when developing FastAPI web APIs with uv, SQLAlchemy 2.0 async, Pydantic v2,
  repository/service/router layered architecture, pytest/polyfactory, ruff/mypy strict.
  Also use when scaffolding a new FastAPI project (scaffold.sh) or adding a CRUD module
  (add-module.sh). Do NOT use for non-Python projects or non-FastAPI Python web frameworks
  (Django, Flask, Starlette alone).
agent_rules:
  - "No emojis unless explicitly requested."
  - "ALWAYS run ruff, mypy, and pytest after making changes."
  - "ALWAYS read a file before editing it."
  - "NEVER commit unless explicitly asked."
---

## Overview

This skill captures conventions for building FastAPI applications with a layered architecture, async SQLAlchemy, Pydantic v2, and pytest-based testing.

## Quick Start

Scaffold a new project in seconds:

```bash
# From the skill directory:
./scripts/scaffold.sh ./my-project my_api

cd ./my-project
uv sync --group dev
cp .env.example .env
# Edit .env with your database URL, then:
uv run uvicorn my_api.api.main:app --reload
```

Add a new CRUD module (model → schema → repo → service → router → tests):

```bash
./scripts/add-module.sh product products my_api
```

Run the full check suite (lint + format-check + typecheck + test):

```bash
./scripts/check.sh ./my-project
```

## Documentation Index

Detailed reference files are in the `docs/` directory:

| File | Content |
|---|---|
| `docs/architecture.md` | Layer diagrams, data flow, dependency matrix |
| `docs/project-structure.md` | Directory tree, file conventions |
| `docs/database.md` | Engine, session, models, config |
| `docs/schemas.md` | Pydantic v2, paginated response, validators |
| `docs/repository.md` | BaseRepository + CRUD + custom queries |
| `docs/service.md` | Business logic, exceptions, DI |
| `docs/api.md` | Routers, deps, error handlers, middleware |
| `docs/testing.md` | conftest layers, factories, test patterns |
| `docs/tooling.md` | ruff, mypy, pytest, Makefile, uv |
| `docs/deployment.md` | Dockerfile pattern |

The agent should fetch the relevant file(s) from `docs/` when implementing a specific layer.

## Scripts

This skill ships with automation scripts in `scripts/`:

| Script | Purpose |
|---|---|
| `scaffold.sh` | Generate a complete FastAPI project from scratch |
| `add-module.sh` | Generate a full CRUD module (all layers + tests) |
| `check.sh` | Run lint, format-check, typecheck, and tests |

### scaffold.sh

```bash
./scripts/scaffold.sh <project-dir> <package-name>
```

Creates the full project structure, `pyproject.toml`, `Makefile`, `Dockerfile`, `.env.example`,
and all base layer files (`config.py`, `database.py`, `exceptions.py`, `api/main.py`, etc.).
Replaces `<package>` everywhere with the given package name.

### add-module.sh

```bash
./scripts/add-module.sh <entity-singular> <entity-plural> [package-name]
```

Generates all files for a new entity: model, schema, repository, service, router, DI deps,
and tests (router, service, repository + factory). Auto-registers the router in `main.py`.
Auto-detects the package name if omitted.

### check.sh

```bash
./scripts/check.sh [project-dir]
```

Runs `ruff check`, `mypy`, and `pytest` in sequence. Useful as a pre-commit gate or CI step.

## References

When implementing, the agent should fetch `reference/links.md` for
official documentation links in case of lack of info in skill. The hidden Git references are available by direct path lookup
when the agent needs to check implementation specifics.
