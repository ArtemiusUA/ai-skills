# Project Structure

```
<project>/
├── pyproject.toml
├── Makefile
├── Dockerfile
├── .env
├── .env.example
├── .gitignore
├── .editorconfig
├── uv.lock
├── <package>/
│   ├── __init__.py
│   ├── config.py
│   ├── database.py
│   ├── exceptions.py
│   ├── logging_config.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── deps.py
│   │   └── routers/
│   │       ├── __init__.py
│   │       ├── utils.py
│   │       ├── entities.py
│   │       └── ...
│   ├── models/
│   │   ├── __init__.py
│   │   ├── entity.py
│   │   └── ...
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── entity.py
│   │   └── ...
│   ├── repositories/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── entities.py
│   │   └── ...
│   └── services/
│       ├── __init__.py
│       ├── entities.py
│       └── ...
└── tests/
    ├── __init__.py
    ├── conftest.py
    ├── api/
    │   ├── __init__.py
    │   └── routers/
    │       ├── __init__.py
    │       ├── conftest.py
    │       ├── test_entities.py
    │       └── ...
    ├── factories/
    │   ├── __init__.py
    │   └── models.py
    ├── repositories/
    │   ├── __init__.py
    │   ├── conftest.py
    │   ├── test_entities.py
    │   └── ...
    └── services/
        ├── __init__.py
        ├── conftest.py
        ├── test_entities.py
        └── ...
```
