---
name: django-project
description: >
  Use when developing Django applications with pragmatic layered architecture
  (models/services/selectors/views). Covers Django ORM, DRF serializers/views,
  caching strategy, testing, and app organization. Do NOT use for non-Django
  Python projects (FastAPI, Flask, Starlette).
agent_rules:
  - "No emojis unless explicitly requested."
  - "ALWAYS read the relevant docs/*.md file before implementing a specific layer."
  - "ALWAYS read a file before editing it."
  - "NEVER commit unless explicitly asked."
---

## Overview

This skill captures conventions for building Django applications with a pragmatic layered architecture. It uses Django's strengths (ORM, Admin, Auth, Migrations, Forms/DRF) while keeping business logic easy to find and avoiding "fat views" or overly complex "fat models." It does not introduce unnecessary abstractions like repositories or dependency injection everywhere.
This skill describes things on high level. More explicit examples will be added later.

## Documentation Index

Detailed reference files are in the `docs/` directory:

| File | Content |
|---|---|
| `docs/architecture.md` | Layer responsibilities, dependency direction, principles, summary table |
| `docs/project-structure.md` | Directory tree, app structure, organization rules |
| `docs/models.md` | Domain behavior, invariants, boundaries |
| `docs/services.md` | Business workflows, transactions, orchestration |
| `docs/selectors.md` | Read queries, query optimization, caching |
| `docs/views-api.md` | Views, serializers, HTTP concerns |
| `docs/tasks.md` | Background execution guidelines |
| `docs/signals.md` | Signal usage boundaries |
| `docs/caching.md` | Read cache, invalidation, external API cache |
| `docs/testing.md` | Focus areas for unit and integration tests |

The agent should fetch the relevant file(s) from `docs/` when implementing a specific layer.

## References

See `reference/links.md` for official Django and DRF documentation links.
