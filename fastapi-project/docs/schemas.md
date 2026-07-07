# Schemas (Pydantic v2)

- Request schemas: plain `BaseModel` with `Field(...)` validators.
- Response schemas: `BaseModel` with `model_config = ConfigDict(from_attributes=True)`.
- Use generic `PaginatedResponse[T]` for list endpoints.
- Use `Field(pattern=r"^...$")` for constrained string enums.
- Use `Field(gt=0)` for positive numeric values.

```python
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class EntityCreate(BaseModel):
    name: str = Field(max_length=500)


class EntityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime
```

## Paginated Response

Define in a separate `schemas/paginated.py` module:

```python
from typing import Any, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class PaginatedResponse[T](BaseModel):
    items: list[T]
    total: int
    skip: int
    limit: int
    has_next: bool
```

Import from the package: `from <package>.schemas import PaginatedResponse`.
