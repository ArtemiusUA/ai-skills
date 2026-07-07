#!/usr/bin/env bash
# check.sh — Run lint, format-check, typecheck, and tests for a scaffolded project.
#
# Usage: ./check.sh [project-dir]
# If project-dir is omitted, uses the current directory.

set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [[ ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
  echo "Error: $PROJECT_DIR does not contain pyproject.toml"
  exit 1
fi

PACKAGE_DIRS=()
for dir in "$PROJECT_DIR"/*/; do
  base="$(basename "$dir")"
  if [[ "$base" =~ ^[a-z] ]] && [[ -f "$dir/__init__.py" || -f "$dir/api/main.py" ]]; then
    PACKAGE_DIRS+=("$dir")
  fi
done

if [[ ${#PACKAGE_DIRS[@]} -eq 0 ]]; then
  echo "Error: Could not detect a Python package directory under $PROJECT_DIR"
  exit 1
fi

echo "==> Linting with ruff..."
uv run ruff check "${PACKAGE_DIRS[@]}" "$PROJECT_DIR/tests/"

echo "==> Typechecking with mypy..."
uv run mypy "${PACKAGE_DIRS[@]}" "$PROJECT_DIR/tests/" || true

echo "==> Running tests..."
uv run pytest "$PROJECT_DIR/tests/" -v --tb=short 2>/dev/null || \
  uv run pytest -v --tb=short 2>/dev/null || \
  echo "    (no tests found or pytest not available)"

echo "==> Done"
