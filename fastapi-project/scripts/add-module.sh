#!/usr/bin/env bash
# add-module.sh — Generate a new entity module (model, schema, repo, service, router, tests)
#
# Usage:
#   ./add-module.sh <entity-singular> <entity-plural> [package-name] [project-dir]
#
# Example:
#   ./add-module.sh product products my_api .
#   ./add-module.sh product products          # auto-detect package in cwd
#
# If project-dir is omitted, the current working directory is used.
# If package-name is omitted, the first snake_case directory under the project root is auto-detected.

set -euo pipefail

sed_in_place() {
  local file="$1"
  local expr="$2"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$expr" "$file"
  else
    sed -i "$expr" "$file"
  fi
}

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <entity-singular> <entity-plural> [package-name] [project-dir]"
  echo ""
  echo "Args:"
  echo "  entity-singular   Singular name (e.g. product, category)"
  echo "  entity-plural     Plural name (e.g. products, categories)"
  echo "  package-name      Python package (auto-detected if omitted)"
  echo "  project-dir       Project root directory (default: cwd)"
  exit 1
fi

SINGULAR="$1"
PLURAL="$2"
PACKAGE_NAME="${3:-}"
PROJECT_DIR="${4:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Convert to proper casing
SINGULAR_LOWER="$(echo "$SINGULAR" | tr '[:upper:]' '[:lower:]')"
PLURAL_LOWER="$(echo "$PLURAL" | tr '[:upper:]' '[:lower:]')"
SINGULAR_PASCAL="$(echo "$SINGULAR_LOWER" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g' | sed 's/ //g')"
PLURAL_PASCAL="$(echo "$PLURAL_LOWER" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g' | sed 's/ //g')"

# Auto-detect package name from project root
if [[ -z "$PACKAGE_NAME" ]]; then
  for item in "$PROJECT_DIR"/*/; do
    basename_item="$(basename "$item")"
    if [[ "$basename_item" =~ ^[a-z][a-z0-9_]*$ ]] && \
       [[ -f "$item/__init__.py" || -f "$item/api/main.py" ]]; then
      PACKAGE_NAME="$basename_item"
      break
    fi
  done
  if [[ -z "$PACKAGE_NAME" ]]; then
    echo "Error: Could not auto-detect package name. Specify it as third argument."
    exit 1
  fi
  echo "==> Auto-detected package: $PACKAGE_NAME"
fi

PACKAGE_DIR="$PROJECT_DIR/$PACKAGE_NAME"
TESTS_DIR="$PROJECT_DIR/tests"

# Verify project structure
if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "Error: Package directory $PACKAGE_DIR does not exist."
  exit 1
fi

echo "==> Generating module: $SINGULAR_PASCAL ($PLURAL_LOWER)"

# --- Model ---
cat >> "$PACKAGE_DIR/models/${PLURAL_LOWER}.py" <<MODEL
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Identity, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from $PACKAGE_NAME.database import Base


class ${SINGULAR_PASCAL}(Base):
    __tablename__ = "${PLURAL_LOWER}"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
MODEL
echo "  + $PACKAGE_DIR/models/${PLURAL_LOWER}.py"

touch "$PACKAGE_DIR/models/__init__.py"

# --- Schema ---
cat >> "$PACKAGE_DIR/schemas/${PLURAL_LOWER}.py" <<SCHEMA
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ${SINGULAR_PASCAL}Create(BaseModel):
    name: str = Field(max_length=500)


class ${SINGULAR_PASCAL}Update(BaseModel):
    name: str | None = Field(default=None, max_length=500)


class ${SINGULAR_PASCAL}Response(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime
SCHEMA
echo "  + $PACKAGE_DIR/schemas/${PLURAL_LOWER}.py"

touch "$PACKAGE_DIR/schemas/__init__.py"

# --- Repository ---
cat >> "$PACKAGE_DIR/repositories/${PLURAL_LOWER}.py" <<REPO
from $PACKAGE_NAME.models.${PLURAL_LOWER} import ${SINGULAR_PASCAL}
from $PACKAGE_NAME.repositories.base import BaseRepository


class ${SINGULAR_PASCAL}Repository(BaseRepository[${SINGULAR_PASCAL}]):
    model = ${SINGULAR_PASCAL}
REPO
echo "  + $PACKAGE_DIR/repositories/${PLURAL_LOWER}.py"

touch "$PACKAGE_DIR/repositories/__init__.py"

# --- Service ---
cat >> "$PACKAGE_DIR/services/${PLURAL_LOWER}.py" <<SERVICE
from $PACKAGE_NAME.exceptions import NotFoundError
from $PACKAGE_NAME.repositories.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Repository
from $PACKAGE_NAME.schemas.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Create


class ${SINGULAR_PASCAL}Service:
    def __init__(self, repo: ${SINGULAR_PASCAL}Repository):
        self.repo = repo

    async def create(self, data: ${SINGULAR_PASCAL}Create):
        obj = await self.repo.add(**data.model_dump())
        await self.repo.commit()
        return obj

    async def get(self, ${SINGULAR_LOWER}_id: int):
        obj = await self.repo.get(${SINGULAR_LOWER}_id)
        if not obj:
            raise NotFoundError(f"${SINGULAR_PASCAL} {${SINGULAR_LOWER}_id} not found")
        return obj

    async def list(self, skip: int = 0, limit: int = 100):
        items = await self.repo.list(skip=skip, limit=limit)
        total = await self.repo.count()
        return items, total

    async def update(self, ${SINGULAR_LOWER}_id: int, data: ${SINGULAR_PASCAL}Create):
        obj = await self.repo.update(${SINGULAR_LOWER}_id, **data.model_dump())
        if not obj:
            raise NotFoundError(f"${SINGULAR_PASCAL} {${SINGULAR_LOWER}_id} not found")
        await self.repo.commit()
        return obj

    async def delete(self, ${SINGULAR_LOWER}_id: int):
        deleted = await self.repo.delete(${SINGULAR_LOWER}_id)
        if not deleted:
            raise NotFoundError(f"${SINGULAR_PASCAL} ${SINGULAR_LOWER}_id not found")
        await self.repo.commit()
SERVICE
echo "  + $PACKAGE_DIR/services/${PLURAL_LOWER}.py"

touch "$PACKAGE_DIR/services/__init__.py"

# --- Router ---
cat >> "$PACKAGE_DIR/api/routers/${PLURAL_LOWER}.py" <<ROUTER
from fastapi import APIRouter, Depends

from $PACKAGE_NAME.api.deps import get_${SINGULAR_LOWER}_service
from $PACKAGE_NAME.api.routers.utils import paginated
from $PACKAGE_NAME.schemas import PaginatedResponse
from $PACKAGE_NAME.schemas.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Create, ${SINGULAR_PASCAL}Update, ${SINGULAR_PASCAL}Response
from $PACKAGE_NAME.services.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Service

router = APIRouter(prefix="/${PLURAL_LOWER}", tags=["${PLURAL_LOWER}"])


@router.post("/", response_model=${SINGULAR_PASCAL}Response, status_code=201)
async def create(
    data: ${SINGULAR_PASCAL}Create, service: ${SINGULAR_PASCAL}Service = Depends(get_${SINGULAR_LOWER}_service)
):
    return await service.create(data)


@router.get("/", response_model=PaginatedResponse[${SINGULAR_PASCAL}Response])
async def list_items(
    skip: int = 0,
    limit: int = 100,
    service: ${SINGULAR_PASCAL}Service = Depends(get_${SINGULAR_LOWER}_service),
):
    items, total = await service.list(skip=skip, limit=limit)
    return paginated(items, total, skip, limit)


@router.get("/{${SINGULAR_LOWER}_id}", response_model=${SINGULAR_PASCAL}Response)
async def get(${SINGULAR_LOWER}_id: int, service: ${SINGULAR_PASCAL}Service = Depends(get_${SINGULAR_LOWER}_service)):
    return await service.get(${SINGULAR_LOWER}_id)


@router.put("/{${SINGULAR_LOWER}_id}", response_model=${SINGULAR_PASCAL}Response)
async def update(
    ${SINGULAR_LOWER}_id: int,
    data: ${SINGULAR_PASCAL}Update,
    service: ${SINGULAR_PASCAL}Service = Depends(get_${SINGULAR_LOWER}_service),
):
    return await service.update(${SINGULAR_LOWER}_id, data)


@router.delete("/{${SINGULAR_LOWER}_id}", status_code=204)
async def delete(
    ${SINGULAR_LOWER}_id: int,
    service: ${SINGULAR_PASCAL}Service = Depends(get_${SINGULAR_LOWER}_service),
):
    await service.delete(${SINGULAR_LOWER}_id)
ROUTER
echo "  + $PACKAGE_DIR/api/routers/${PLURAL_LOWER}.py"

# --- Router deps (appended to api/deps.py) ---
touch "$PACKAGE_DIR/api/deps.py"
DEPS_FILE="$PACKAGE_DIR/api/deps.py"
if ! grep -q "def get_${SINGULAR_LOWER}_service" "$DEPS_FILE" 2>/dev/null; then
  cat >> "$DEPS_FILE" <<DEPS

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from $PACKAGE_NAME.database import get_db
from $PACKAGE_NAME.repositories.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Repository
from $PACKAGE_NAME.services.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Service


def get_${SINGULAR_LOWER}_service(db: AsyncSession = Depends(get_db)) -> ${SINGULAR_PASCAL}Service:
    return ${SINGULAR_PASCAL}Service(${SINGULAR_PASCAL}Repository(db))
DEPS
  echo "  ~ $DEPS_FILE (added ${SINGULAR_LOWER} service DI)"
fi

# Register router in main.py (insert before app.include_router(entities.router) if exists, or before @app.get("/health"))
MAIN_FILE="$PACKAGE_DIR/api/main.py"
IMPORT_LINE="from $PACKAGE_NAME.api.routers import ${PLURAL_LOWER}"
REGISTER_LINE="app.include_router(${PLURAL_LOWER}.router)"

if [[ -f "$MAIN_FILE" ]]; then
  if ! grep -qF "$IMPORT_LINE" "$MAIN_FILE"; then
    sed_in_place "$MAIN_FILE" "s/^from $PACKAGE_NAME.api.routers import entities/from $PACKAGE_NAME.api.routers import entities\\
from $PACKAGE_NAME.api.routers import ${PLURAL_LOWER}/"
    sed_in_place "$MAIN_FILE" "s/^app.include_router(entities.router)/app.include_router(entities.router)\\
app.include_router(${PLURAL_LOWER}.router)/"
    echo "  ~ $MAIN_FILE (registered router)"
  fi
fi

# --- Test: Repository ---
cat >> "$TESTS_DIR/repositories/test_${PLURAL_LOWER}.py" <<TEST_REPO
from $PACKAGE_NAME.repositories.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Repository
from tests.factories.models import ${SINGULAR_PASCAL}Factory, model_to_dict


class Test${SINGULAR_PASCAL}Repository:
    async def test_create(self, session):
        repo = ${SINGULAR_PASCAL}Repository(session)
        obj = await repo.add(**model_to_dict(${SINGULAR_PASCAL}Factory.build()))
        await repo.commit()
        assert obj.id is not None

    async def test_get(self, session):
        repo = ${SINGULAR_PASCAL}Repository(session)
        created = await repo.add(**model_to_dict(${SINGULAR_PASCAL}Factory.build()))
        await repo.commit()
        result = await repo.get(created.id)
        assert result is not None
        assert result.id == created.id

    async def test_list_with_pagination(self, session):
        repo = ${SINGULAR_PASCAL}Repository(session)
        for _ in range(5):
            await repo.add(**model_to_dict(${SINGULAR_PASCAL}Factory.build()))
            await repo.commit()
        results = await repo.list(skip=2, limit=2)
        assert len(results) == 2

    async def test_update(self, session):
        repo = ${SINGULAR_PASCAL}Repository(session)
        created = await repo.add(**model_to_dict(${SINGULAR_PASCAL}Factory.build()))
        await repo.commit()
        updated = await repo.update(created.id, name="Updated")
        assert updated is not None
        assert updated.name == "Updated"

    async def test_delete(self, session):
        repo = ${SINGULAR_PASCAL}Repository(session)
        created = await repo.add(**model_to_dict(${SINGULAR_PASCAL}Factory.build()))
        await repo.commit()
        deleted = await repo.delete(created.id)
        assert deleted is True
        assert await repo.get(created.id) is None
TEST_REPO
echo "  + tests/repositories/test_${PLURAL_LOWER}.py"

# --- Test: Service ---
mkdir -p "$PROJECT_DIR/tests/services"
cat >> "$PROJECT_DIR/tests/services/test_${PLURAL_LOWER}.py" <<TEST_SVC
import pytest
from unittest.mock import call

from $PACKAGE_NAME.exceptions import NotFoundError
from $PACKAGE_NAME.schemas.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Create
from $PACKAGE_NAME.services.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Service


class Test${SINGULAR_PASCAL}Service:
    async def test_create(self, mock_${SINGULAR_LOWER}_repo):
        data = ${SINGULAR_PASCAL}Create(name="Test")
        expected = object()
        mock_${SINGULAR_LOWER}_repo.add.return_value = expected

        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        result = await svc.create(data)

        assert mock_${SINGULAR_LOWER}_repo.add.call_args_list == [call(**data.model_dump())]
        assert result is expected

    async def test_get_not_found(self, mock_${SINGULAR_LOWER}_repo):
        mock_${SINGULAR_LOWER}_repo.get.return_value = None
        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        with pytest.raises(NotFoundError):
            await svc.get(999)

    async def test_list(self, mock_${SINGULAR_LOWER}_repo):
        mock_${SINGULAR_LOWER}_repo.list.return_value = [object(), object()]
        mock_${SINGULAR_LOWER}_repo.count.return_value = 2
        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        items, total = await svc.list()
        assert total == 2

    async def test_update(self, mock_${SINGULAR_LOWER}_repo):
        data = ${SINGULAR_PASCAL}Create(name="Updated")
        expected = object()
        mock_${SINGULAR_LOWER}_repo.update.return_value = expected

        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        result = await svc.update(1, data)

        mock_${SINGULAR_LOWER}_repo.update.assert_called_once_with(1, **data.model_dump())
        assert result is expected

    async def test_delete(self, mock_${SINGULAR_LOWER}_repo):
        mock_${SINGULAR_LOWER}_repo.delete.return_value = True
        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        await svc.delete(1)
        mock_${SINGULAR_LOWER}_repo.delete.assert_called_once_with(1)

    async def test_delete_not_found(self, mock_${SINGULAR_LOWER}_repo):
        mock_${SINGULAR_LOWER}_repo.delete.return_value = False
        svc = ${SINGULAR_PASCAL}Service(mock_${SINGULAR_LOWER}_repo)
        with pytest.raises(NotFoundError):
            await svc.delete(999)
TEST_SVC
echo "  + tests/services/test_${PLURAL_LOWER}.py"

# --- Service test fixture ---
SVC_CONFTEST="$PROJECT_DIR/tests/services/conftest.py"
if ! grep -q "def mock_${SINGULAR_LOWER}_repo" "$SVC_CONFTEST" 2>/dev/null; then
  cat >> "$SVC_CONFTEST" <<SVC_FIXTURE

@pytest.fixture
def mock_${SINGULAR_LOWER}_repo():
    return AsyncMock()
SVC_FIXTURE
  # Ensure AsyncMock is imported
  if ! grep -q "from unittest.mock import AsyncMock" "$SVC_CONFTEST" 2>/dev/null; then
    sed_in_place "$SVC_CONFTEST" "1s/^/from unittest.mock import AsyncMock\n\n/"
  fi
  # Ensure pytest is imported
  if ! grep -q "^import pytest" "$SVC_CONFTEST" 2>/dev/null; then
    sed_in_place "$SVC_CONFTEST" "1s/^/import pytest\n/"
  fi
  echo "  ~ $SVC_CONFTEST (added mock_${SINGULAR_LOWER}_repo fixture)"
fi

# --- Test: Router ---
mkdir -p "$PROJECT_DIR/tests/api/routers"
cat >> "$PROJECT_DIR/tests/api/routers/test_${PLURAL_LOWER}.py" <<TEST_ROUTER
from datetime import datetime

from $PACKAGE_NAME.exceptions import NotFoundError
from $PACKAGE_NAME.schemas import PaginatedResponse
from $PACKAGE_NAME.schemas.${PLURAL_LOWER} import ${SINGULAR_PASCAL}Response


class Test${SINGULAR_PASCAL}Router:
    async def test_create(self, client, mock_${SINGULAR_LOWER}_service):
        mock_${SINGULAR_LOWER}_service.create.return_value = ${SINGULAR_PASCAL}Response(
            id=1,
            name="Test",
            created_at=datetime(2026, 1, 1),
        )
        resp = await client.post("/${PLURAL_LOWER}/", json={"name": "Test"})
        assert resp.status_code == 201
        ${SINGULAR_PASCAL}Response.model_validate(resp.json())

    async def test_list(self, client, mock_${SINGULAR_LOWER}_service):
        mock_${SINGULAR_LOWER}_service.list.return_value = ([], 0)
        resp = await client.get("/${PLURAL_LOWER}/")
        assert resp.status_code == 200
        PaginatedResponse[${SINGULAR_PASCAL}Response].model_validate(resp.json())

    async def test_get_not_found(self, client, mock_${SINGULAR_LOWER}_service):
        mock_${SINGULAR_LOWER}_service.get.side_effect = NotFoundError(f"${SINGULAR_PASCAL} 99999 not found")
        resp = await client.get("/${PLURAL_LOWER}/99999")
        assert resp.status_code == 404

    async def test_update(self, client, mock_${SINGULAR_LOWER}_service):
        mock_${SINGULAR_LOWER}_service.update.return_value = ${SINGULAR_PASCAL}Response(
            id=1,
            name="Updated",
            created_at=datetime(2026, 1, 1),
        )
        resp = await client.put("/${PLURAL_LOWER}/1", json={"name": "Updated"})
        assert resp.status_code == 200
        ${SINGULAR_PASCAL}Response.model_validate(resp.json())

    async def test_delete(self, client, mock_${SINGULAR_LOWER}_service):
        resp = await client.delete("/${PLURAL_LOWER}/1")
        assert resp.status_code == 204
TEST_ROUTER
echo "  + tests/api/routers/test_${PLURAL_LOWER}.py"

# --- Factory ---
FACTORY_FILE="$PROJECT_DIR/tests/factories/models.py"
if [[ -f "$FACTORY_FILE" ]]; then
  if ! grep -q "${SINGULAR_PASCAL}Factory" "$FACTORY_FILE"; then
    cat >> "$FACTORY_FILE" <<FACTORY


class ${SINGULAR_PASCAL}Factory(SQLAlchemyFactory[${SINGULAR_PASCAL}]):
    __model__ = ${SINGULAR_PASCAL}
    __set_relationships__ = False
FACTORY
    # Add import at top
    sed_in_place "$FACTORY_FILE" "1s/^/from $PACKAGE_NAME.models.${PLURAL_LOWER} import ${SINGULAR_PASCAL}\n/"
    echo "  ~ tests/factories/models.py (added factory)"
  fi
fi

echo ""
echo "==> Module $SINGULAR_PASCAL generated! Summary:"
echo "  - Model:      models/${PLURAL_LOWER}.py"
echo "  - Schema:     schemas/${PLURAL_LOWER}.py"
echo "  - Repository: repositories/${PLURAL_LOWER}.py"
echo "  - Service:    services/${PLURAL_LOWER}.py"
echo "  - Router:     api/routers/${PLURAL_LOWER}.py"
echo "  - Deps:       api/deps.py (appended)"
echo "  - Tests:      tests/{api,repositories,services}/"
echo ""
echo "Don't forget to run: uv run ruff check --fix src/ tests/ && uv run pytest"
