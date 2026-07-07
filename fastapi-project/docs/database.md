# Database Layer

## Engine & Session (database.py)

```python
import logging

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from <package>.config import settings

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
```

## Configuration (config.py)

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://user:pass@localhost:5432/db"
    app_title: str = "My API"
    app_version: str = "0.1.0"
    log_level: str = "INFO"
    cors_origins: list[str] = ["*"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
```

## Models

- Use SQLAlchemy 2.0 `Mapped` / `mapped_column` style.
- Inherit from `Base` (DeclarativeBase).
- Use `BigInteger` + `Identity()` for auto-increment PKs.
- Use `UUID(as_uuid=True)` for UUID PKs with `default=uuid.uuid4`.
- Add `__tablename__` (snake_case plural).
- Use `CheckConstraint` and `UniqueConstraint` via `__table_args__`.
- Timestamps: `DateTime(timezone=True)` with `server_default=func.now()`.

```python
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Identity, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from <package>.database import Base


class Entity(Base):
    __tablename__ = "entities"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
```
