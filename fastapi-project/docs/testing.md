# Testing Conventions

## Test Structure
- Tests mirror source structure: `tests/api/routers/`, `tests/repositories/`, `tests/services/`.
- Group tests in classes named `Test<Entity><Layer>`.
- Use `pytest-asyncio` with `asyncio_mode = "auto"` (no need for `@pytest.mark.asyncio`).

## conftest.py Layers
- `tests/conftest.py`: Override `DATABASE_URL` env var for test DB.
- `tests/api/routers/conftest.py`: Mock services with `AsyncMock`, create `client` fixture with `ASGITransport`.
- `tests/repositories/conftest.py`: Real test DB engine, session, and cleanup (TRUNCATE).
- `tests/services/conftest.py`: Mock all repos with `AsyncMock`.

## Router Tests (mocked services)

```python
from datetime import datetime

from <package>.exceptions import NotFoundError
from <package>.schemas import EntityResponse, PaginatedResponse


class TestEntityRouter:
    async def test_create(self, client, mock_entity_service):
        mock_entity_service.create.return_value = EntityResponse(
            id=1,
            name="Test",
            created_at=datetime(2026, 1, 1),
        )
        resp = await client.post("/entities/", json={"name": "Test"})
        assert resp.status_code == 201
        EntityResponse.model_validate(resp.json())

    async def test_list(self, client, mock_entity_service):
        mock_entity_service.list.return_value = ([], 0)
        resp = await client.get("/entities/")
        assert resp.status_code == 200
        PaginatedResponse[EntityResponse].model_validate(resp.json())

    async def test_update(self, client, mock_entity_service):
        mock_entity_service.update.return_value = EntityResponse(
            id=1,
            name="Updated",
            created_at=datetime(2026, 1, 1),
        )
        resp = await client.put("/entities/1", json={"name": "Updated"})
        assert resp.status_code == 200
        EntityResponse.model_validate(resp.json())

    async def test_delete(self, client, mock_entity_service):
        resp = await client.delete("/entities/1")
        assert resp.status_code == 204

    async def test_get_not_found(self, client, mock_entity_service):
        mock_entity_service.get.side_effect = NotFoundError("Entity 99999 not found")
        resp = await client.get("/entities/99999")
        assert resp.status_code == 404
```

## Service Tests (mocked repos)

```python
import pytest
from unittest.mock import call

from <package>.exceptions import NotFoundError
from <package>.schemas import EntityCreate
from <package>.services import EntityService


class TestEntityService:
    async def test_create(self, mock_entity_repo):
        data = EntityCreate(name="Test")
        expected = object()
        mock_entity_repo.add.return_value = expected

        svc = EntityService(mock_entity_repo)
        result = await svc.create(data)

        assert mock_entity_repo.add.call_args_list == [call(**data.model_dump())]
        assert result is expected

    async def test_get_not_found(self, mock_entity_repo):
        mock_entity_repo.get.return_value = None
        svc = EntityService(mock_entity_repo)
        with pytest.raises(NotFoundError):
            await svc.get(999)

    async def test_list(self, mock_entity_repo):
        mock_entity_repo.list.return_value = [object(), object()]
        mock_entity_repo.count.return_value = 2
        svc = EntityService(mock_entity_repo)
        items, total = await svc.list()
        assert total == 2

    async def test_update(self, mock_entity_repo):
        data = EntityCreate(name="Updated")
        expected = object()
        mock_entity_repo.update.return_value = expected

        svc = EntityService(mock_entity_repo)
        result = await svc.update(1, data)

        mock_entity_repo.update.assert_called_once_with(1, **data.model_dump())
        assert result is expected

    async def test_delete(self, mock_entity_repo):
        mock_entity_repo.delete.return_value = True
        svc = EntityService(mock_entity_repo)
        await svc.delete(1)
        mock_entity_repo.delete.assert_called_once_with(1)

    async def test_delete_not_found(self, mock_entity_repo):
        mock_entity_repo.delete.return_value = False
        svc = EntityService(mock_entity_repo)
        with pytest.raises(NotFoundError):
            await svc.delete(999)
```

## Repository Tests (real DB)

```python
from <package>.repositories import EntityRepository
from tests.factories.models import EntityFactory, model_to_dict


class TestEntityRepository:
    async def test_create(self, session):
        repo = EntityRepository(session)
        obj = await repo.add(**model_to_dict(EntityFactory.build()))
        await repo.commit()
        assert obj.id is not None

    async def test_get(self, session):
        repo = EntityRepository(session)
        created = await repo.add(**model_to_dict(EntityFactory.build()))
        await repo.commit()
        result = await repo.get(created.id)
        assert result is not None
        assert result.id == created.id

    async def test_list_with_pagination(self, session):
        repo = EntityRepository(session)
        for _ in range(5):
            await repo.add(**model_to_dict(EntityFactory.build()))
            await repo.commit()
        results = await repo.list(skip=2, limit=2)
        assert len(results) == 2

    async def test_update(self, session):
        repo = EntityRepository(session)
        created = await repo.add(**model_to_dict(EntityFactory.build()))
        await repo.commit()
        updated = await repo.update(created.id, name="Updated")
        assert updated is not None
        assert updated.name == "Updated"

    async def test_delete(self, session):
        repo = EntityRepository(session)
        created = await repo.add(**model_to_dict(EntityFactory.build()))
        await repo.commit()
        deleted = await repo.delete(created.id)
        assert deleted is True
        assert await repo.get(created.id) is None
```

## Factories (polyfactory SQLAlchemyFactory)

```python
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory
from sqlalchemy.orm import DeclarativeBase

from <package>.models import Entity


def model_to_dict(model: DeclarativeBase) -> dict:
    return {
        c.name: getattr(model, c.name)
        for c in model.__table__.columns
        if c.identity is None
    }


class EntityFactory(SQLAlchemyFactory[Entity]):
    __model__ = Entity
    __set_relationships__ = False
```

## API Router Test Fixtures (conftest.py)

```python
from unittest.mock import AsyncMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from <package>.api.deps import get_entity_service
from <package>.api.main import app as _app


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
```
