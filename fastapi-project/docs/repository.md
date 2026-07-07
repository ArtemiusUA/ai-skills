# Repository Layer

## Base Repository (repositories/base.py)

```python
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
```

## Concrete Repository

```python
from <package>.models import Entity
from <package>.repositories.base import BaseRepository


class EntityRepository(BaseRepository[Entity]):
    model = Entity
```

For complex queries (e.g., upserts), add custom methods using PostgreSQL dialect features:

```python
from sqlalchemy.dialects.postgresql import insert as pg_insert


async def upsert(self, entry: SomeModel) -> SomeModel:
    result = await self.session.execute(
        pg_insert(SomeModel)
        .values(
            field_a=entry.field_a,
            field_b=entry.field_b,
        )
        .on_conflict_do_update(
            index_elements=["field_a"],
            set_={
                "field_b": SomeModel.field_b + entry.field_b,
            },
        )
        .returning(SomeModel)
    )
    return result.scalar_one()
```
