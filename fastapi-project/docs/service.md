# Service Layer

- Accept repositories via constructor injection.
- Methods call repo methods + commit.
- Return ORM models (Pydantic serialization happens in the router).
- Return `(items, total)` tuple from list methods.
- Raise custom exceptions for business logic violations.

```python
from <package>.exceptions import NotFoundError
from <package>.repositories.entities import EntityRepository
from <package>.schemas import EntityCreate


class EntityService:
    def __init__(self, repo: EntityRepository):
        self.repo = repo

    async def create(self, data: EntityCreate):
        obj = await self.repo.add(**data.model_dump())
        await self.repo.commit()
        return obj

    async def get(self, entity_id: int):
        obj = await self.repo.get(entity_id)
        if not obj:
            raise NotFoundError(f"Entity {entity_id} not found")
        return obj

    async def list(self, skip: int = 0, limit: int = 100):
        items = await self.repo.list(skip=skip, limit=limit)
        total = await self.repo.count()
        return items, total

    async def update(self, entity_id: int, data: EntityCreate):
        obj = await self.repo.update(entity_id, **data.model_dump(exclude_unset=True))
        if not obj:
            raise NotFoundError(f"Entity {entity_id} not found")
        await self.repo.commit()
        return obj

    async def delete(self, entity_id: int):
        deleted = await self.repo.delete(entity_id)
        if not deleted:
            raise NotFoundError(f"Entity {entity_id} not found")
        await self.repo.commit()
```

## Custom Exceptions

```python
class NotFoundError(Exception):
    def __init__(self, detail: str = "Resource not found"):
        self.detail = detail


class BadRequestError(Exception):
    def __init__(self, detail: str = "Bad request"):
        self.detail = detail
```
