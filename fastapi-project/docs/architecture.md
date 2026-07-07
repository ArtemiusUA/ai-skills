# Architecture & Layering

The project follows a **strict layered architecture** with four primary layers. Each layer has a single responsibility and depends only on the layer directly below it. This keeps business logic framework-agnostic and testable.

```
┌──────────────────────────────────────────────────────────┐
│                        API Layer                         │
│  (routers/, deps.py, main.py)                            │
│  - HTTP concerns: request parsing, response serialization │
│  - Depends on: services (via DI), schemas                  │
│  - Knows about: FastAPI, HTTP status codes                 │
├──────────────────────────────────────────────────────────┤
│                      Service Layer                        │
│  (services/)                                              │
│  - Business logic, validation, orchestration              │
│  - Depends on: repositories, schemas                      │
│  - Knows about: domain concepts, exceptions               │
├──────────────────────────────────────────────────────────┤
│                    Repository Layer                       │
│  (repositories/)                                          │
│  - Data access, query building, persistence               │
│  - Depends on: models                                     │
│  - Knows about: SQLAlchemy, SQL                          │
├──────────────────────────────────────────────────────────┤
│                   Model / Schema Layer                    │
│  (models/, schemas/)                                      │
│  - models/: SQLAlchemy ORM definitions (DB shape)         │
│  - schemas/: Pydantic models (API shape)                  │
│  - Depends on: nothing (leaf layer)                       │
└──────────────────────────────────────────────────────────┘
```

## Layer Dependency Rules

| Layer | Can import from | Cannot import from |
|---|---|---|
| `api/` | `services/`, `schemas/` | `repositories/`, `models/` |
| `services/` | `repositories/`, `schemas/`, `exceptions.py` | `api/`, `models/` directly |
| `repositories/` | `models/` | `api/`, `services/`, `schemas/` |
| `models/` | `database.py` (Base) | everything else |
| `schemas/` | nothing | everything else |

Repository and service instances are wired together via **dependency injection** in `api/deps.py`, not through direct instantiation.

## Data Flow

```
HTTP Request
    │
    ▼
Router (api/routers/)          ← parses path/query/body params, calls service
    │
    ▼
Service (services/)            ← validates business rules, calls repos
    │
    ▼
Repository (repositories/)     ← builds queries, persists/retrieves data
    │
    ▼
Model (models/) + DB           ← SQLAlchemy ORM → PostgreSQL
    │
    ▼ (response bubbles up)
Router returns Pydantic schema ← schemas/ serializes ORM via from_attributes
```

## Why This Layering

- **Testability**: Each layer can be tested independently — services with mocked repos, repos with a real DB, routers with mocked services.
- **Swapability**: Swap FastAPI for another framework by replacing only `api/`. Swap PostgreSQL for another DB by replacing only `repositories/`.
- **Responsibility isolation**: Business logic isn't scattered across route handlers. Queries aren't duplicated across services.
- **Framework decoupling**: Services and repositories know nothing about HTTP. They receive clean data objects and return clean data objects.
