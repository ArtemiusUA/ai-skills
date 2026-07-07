# API Layer

## Main App (api/main.py)

```python
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError

from <package>.api.routers import entities
from <package>.config import settings
from <package>.database import engine
from <package>.exceptions import BadRequestError, NotFoundError
from <package>.logging_config import configure_logging

logger = logging.getLogger(__name__)
configure_logging()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("Starting API")
    yield
    logger.info("Shutting down API")
    await engine.dispose()


app = FastAPI(title=settings.app_title, version=settings.app_version, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(IntegrityError)
async def integrity_error_handler(_request: Request, exc: IntegrityError):
    logger.warning("Integrity error: %s", exc)
    detail = str(exc.orig).split("\n")[0] if exc.orig else "Resource conflict"
    return JSONResponse(status_code=409, content={"detail": detail})


@app.exception_handler(NotFoundError)
async def not_found_handler(_request: Request, exc: NotFoundError):
    return JSONResponse(status_code=404, content={"detail": exc.detail})


@app.exception_handler(BadRequestError)
async def bad_request_handler(_request: Request, exc: BadRequestError):
    return JSONResponse(status_code=400, content={"detail": exc.detail})


@app.exception_handler(ValueError)
async def value_error_handler(_request: Request, exc: ValueError):
    return JSONResponse(status_code=422, content={"detail": str(exc)})


@app.exception_handler(Exception)
async def unhandled_error_handler(_request: Request, exc: Exception):
    logger.exception("Unhandled error: %s", exc)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


app.include_router(entities.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
```

## Dependency Injection (api/deps.py)

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from <package>.database import get_db
from <package>.repositories.entities import EntityRepository
from <package>.services.entities import EntityService


def get_entity_service(db: AsyncSession = Depends(get_db)) -> EntityService:
    return EntityService(EntityRepository(db))
```

## Router Convention

```python
from fastapi import APIRouter, Depends

from <package>.api.deps import get_entity_service
from <package>.api.routers.utils import paginated
from <package>.schemas import EntityCreate, EntityResponse, PaginatedResponse
from <package>.services.entities import EntityService

router = APIRouter(prefix="/entities", tags=["entities"])


@router.post("/", response_model=EntityResponse, status_code=201)
async def create(
    data: EntityCreate, service: EntityService = Depends(get_entity_service)
):
    return await service.create(data)


@router.get("/", response_model=PaginatedResponse[EntityResponse])
async def list_items(
    skip: int = 0,
    limit: int = 100,
    service: EntityService = Depends(get_entity_service),
):
    items, total = await service.list(skip=skip, limit=limit)
    return paginated(items, total, skip, limit)


@router.get("/{entity_id}", response_model=EntityResponse)
async def get(entity_id: int, service: EntityService = Depends(get_entity_service)):
    return await service.get(entity_id)


@router.put("/{entity_id}", response_model=EntityResponse)
async def update(
    entity_id: int,
    data: EntityCreate,
    service: EntityService = Depends(get_entity_service),
):
    return await service.update(entity_id, data)


@router.delete("/{entity_id}", status_code=204)
async def delete(
    entity_id: int,
    service: EntityService = Depends(get_entity_service),
):
    await service.delete(entity_id)
```

## Pagination Utility (api/routers/utils.py)

```python
from typing import Any

from <package>.schemas import PaginatedResponse


def paginated(
    items: list[Any], total: int, skip: int, limit: int
) -> PaginatedResponse[Any]:
    return PaginatedResponse(
        items=items,
        total=total,
        skip=skip,
        limit=limit,
        has_next=(skip + limit < total),
    )
```
