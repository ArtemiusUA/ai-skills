---
name: sqitch-migrations
description: >
  Use when managing database schema changes with Sqitch (any supported engine:
  PostgreSQL, SQLite, MySQL/MariaDB, Oracle, CockroachDB, YugabyteDB, Firebird,
  Vertica, Exasol, Snowflake, ClickHouse): adding new migrations, writing
  deploy/revert/verify scripts, running sqitch commands (deploy, revert,
  verify, rework, tag), and maintaining a Docker-based sqitch workflow.
  Do NOT use for migration tools other than Sqitch (Alembic, Flyway, Goose, etc.).
agent_rules:
  - "No emojis unless explicitly requested."
  - "ALWAYS read the existing deploy/revert/verify files before writing new migrations."
  - "ALWAYS read sqitch.plan and sqitch.conf before adding a new change."
  - "ALWAYS identify the database engine (pg, sqlite, mysql, etc.) from sqitch.conf before writing scripts."
  - "Look up engine-specific SQL syntax in reference/links.md if unsure."
  - "NEVER commit unless explicitly asked."
---

## Overview

[Sqitch](https://sqitch.org/) is a database change management tool that uses  sqitch_pg:
    build:
      context: migrations_pg
      dockerfile: Dockerfile.sqitch
    depends_on:
      postgres:
        condition: service_healthy
    command: ["deploy", "db:pg://user:pass@postgres:5432/dbname"]

  # ── Test database migrations ──────────────────────────────────────────
  sqitch_pg_test:
    build:
      context: migrations_pg
      dockerfile: Dockerfile.sqitch
    depends_on:
      postgres:
        condition: service_healthy
    command: ["deploy", "db:pg://user:pass@postgres:5432/dbname_test"]
a VCS-friendly plan file (`sqitch.plan`) and three SQL scripts per change:
**deploy**, **revert**, and **verify**. It supports many database engines
(PostgreSQL, SQLite, MySQL/MariaDB, Oracle, CockroachDB, YugabyteDB, Firebird,
Vertica, Exasol, Snowflake, ClickHouse).   This skill captures conventions
applicable across all engines, with engine-specific notes where they differ.
It is intended to be universal — adapt the patterns to your project's chosen
engine.

## Repository Structure

A typical Sqitch project layout:

```
migrations/
├── deploy/           # SQL scripts that apply a change
├── revert/           # SQL scripts that undo a change
├── verify/           # SQL scripts that verify a change succeeded
├── sqitch.conf       # Engine & target configuration
└── sqitch.plan       # Ordered list of all changes (plan file)
```

## Adding a New Migration

1. **Identify the engine** – read `sqitch.conf` to find the engine name
   (`pg`, `sqlite`, `mysql`, `oracle`, `cockroach`, `firebird`, `vertica`,
   `exasol`, `snowflake`, `clickhouse`).

2. **Read `sqitch.plan`** – understand what the last change is and what
   dependencies exist.

3. **Read `sqitch.conf`** – confirm engine targets and connection URIs.

4. **Add the change** (name in `snake_case`):

   ```bash
   sqitch add <change_name> \
     --requires <dependency> \
     -n 'Short description of the change.'
   ```

   This creates three stub files (`deploy/<name>.sql`, `revert/<name>.sql`,
   `verify/<name>.sql`) and appends an entry to `sqitch.plan`.

5. **Write `deploy/<name>.sql`** – apply the change. Wrap in transaction
   when the engine supports transactional DDL (PostgreSQL, SQLite). For
   engines without transactional DDL (MySQL), be aware that partially-applied
   changes may leave side effects.

   ```sql
   -- Deploy <change_name>
   -- requires: <dependency>

   BEGIN;

   CREATE TABLE users (
       nickname  TEXT  PRIMARY KEY,
       password  TEXT  NOT NULL,
       timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );

   COMMIT;
   ```

6. **Write `revert/<name>.sql`** – precisely undo the deploy:

   ```sql
   -- Revert <change_name>

   BEGIN;

   DROP TABLE users;

   COMMIT;
   ```

7. **Write `verify/<name>.sql`** – must raise an exception on failure and
   succeed silently when correct. The pattern depends on the engine (see
   [Verify Patterns by Engine](#verify-patterns-by-engine) below).

8. **Test locally**:

   ```bash
   sqitch deploy --verify
   sqitch verify
   sqitch revert -y
   sqitch deploy --verify
   ```

## Verify Patterns by Engine

| Engine | Table verification | Function/object verification |
|--------|-------------------|------------------------------|
| **PostgreSQL** | `SELECT ... FROM tbl WHERE FALSE;` | `SELECT has_function_privilege('schema.func(args)', 'execute');` |
| **SQLite** | `SELECT ... FROM tbl WHERE 0;` | `SELECT 1/COUNT(*) FROM sqlite_master WHERE type='function' AND name='func';` |
| **MySQL** | `SELECT ... FROM tbl WHERE 0;` | `SELECT sqitch.checkit(COUNT(*), 'msg') FROM information_schema.routines WHERE routine_name='func';` |
| **Oracle** | `SELECT ... FROM tbl WHERE 1=0;` | `SELECT 1/COUNT(*) FROM user_objects WHERE object_name='FUNC' AND object_type='FUNCTION';` |
| **Firebird** | `SELECT ... FROM tbl WHERE 1=0;` | Raise exception via `EXECUTE BLOCK` if missing |
| **Vertica** | `SELECT ... FROM tbl WHERE false;` | `SELECT 1/COUNT(*) FROM vs_catalog.user_functions WHERE function_name='func';` |
| **Snowflake** | `SELECT ... FROM tbl WHERE FALSE;` | `SELECT 1/COUNT(*) FROM information_schema.functions WHERE function_name='FUNC';` |

The simplest cross-engine verify pattern for tables is to `SELECT` specific
columns with a false `WHERE` clause – the query fails if the table/column
does not exist but touches no data.

## Key Sqitch Commands

| Command | Purpose |
|---------|---------|
| `sqitch init <project> --uri <uri> --engine <engine>` | Initialize a new Sqitch project (engine: `pg`, `sqlite`, `mysql`, `oracle`, etc.) |
| `sqitch add <name> -r <dep> -n '<note>'` | Add a new change |
| `sqitch deploy [target]` | Deploy pending changes (creates registry on first run) |
| `sqitch deploy --verify` | Deploy and verify each change immediately |
| `sqitch revert [target]` | Revert deployed changes (prompts for confirmation) |
| `sqitch revert -y` | Revert without prompt |
| `sqitch revert --to @HEAD^` | Revert to the change *before* the most recent |
| `sqitch revert --to @ROOT` | Revert to the very first change |
| `sqitch verify [target]` | Verify all deployed changes |
| `sqitch status [target]` | Show deployed / undeployed changes |
| `sqitch log [target]` | Show deployment history |
| `sqitch tag <tagname> -n '<note>'` | Tag the current HEAD change |
| `sqitch rework <name> -r <dep> -n '<note>'` | Rework a change (requires a tag between old & new versions) |
| `sqitch rebase [target]` | Revert all + deploy all in one step |
| `sqitch bundle --dest-dir <dir>` | Bundle scripts/plan/config for distribution |
| `sqitch target add <name> <uri>` | Name a deployment target |
| `sqitch engine add <engine> <target>` | Set a default target for an engine |

## Database URIs

Sqitch connects to databases via [URI::db](https://github.com/libwww-perl/uri-db/)
URIs. The scheme varies by engine:

| Engine | Example URI |
|--------|-------------|
| PostgreSQL | `db:pg://user:pass@host:5432/dbname` |
| CockroachDB | `db:cockroach://root@localhost:26257/dbname` |
| YugabyteDB | `db:pg://user@localhost:5433/dbname` |
| SQLite | `db:sqlite:relative/path.db` or `db:sqlite:/absolute/path.db` |
| MySQL | `db:mysql://user@host/dbname` |
| Oracle | `db:oracle://user:pass@host:1521/SID` |
| Firebird | `db:firebird://user:pass@host:/path/db.fdb` |
| Vertica | `db:vertica://user@host/dbname` |
| Exasol | `db:exasol://user:pass@host:8563/dbname` |
| Snowflake | `db:snowflake://user:pass@account/dbname?warehouse=WH&role=ROLE` |
| ClickHouse | `db:clickhouse://user@host:9000/dbname` |

## Configuration (`sqitch.conf`)

Example for PostgreSQL:

```ini
[core]
  engine = pg
  top_dir = .
  plan_file = sqitch.plan
[engine "pg"]
  target = db:pg://user:pass@host:5432/dbname
  registry = sqitch
  client = psql
[engine "pg_test"]
  target = db:pg://user:pass@host:5432/dbname_test
  registry = sqitch_test
  client = psql
```

Example for SQLite:

```ini
[core]
  engine = sqlite
[engine "sqlite"]
  target = db:sqlite:myapp.db
  registry = sqitch
  client = sqlite3
```

Example for MySQL:

```ini
[core]
  engine = mysql
[engine "mysql"]
  target = db:mysql://root@/myapp
  registry = sqitch
  client = mysql
```

- `target` is the database URI.
- `registry` is where Sqitch stores its own tracking tables (a schema in PG,
  a separate database in MySQL, a separate file in SQLite).
- `client` is the CLI client binary (`psql`, `sqlite3`, `mysql`, etc.).

## Engine-Specific Considerations

| Aspect | PostgreSQL / CockroachDB / YugabyteDB | SQLite | MySQL / MariaDB | Oracle |
|--------|--------------------------------------|--------|-----------------|--------|
| **DDL transactions** | Full support – wrap in `BEGIN;`/`COMMIT;` | Full support – wrap in `BEGIN;`/`COMMIT;` | Not supported – DDL auto-commits | Full support |
| **Registry** | Schema in target database | Separate `.db` file | Separate database | Schema in target database |
| **Functions/Procs** | `CREATE OR REPLACE FUNCTION` | No functions | `DELIMITER // CREATE FUNCTION` | `CREATE OR REPLACE FUNCTION` |
| **Verify helpers** | Built-in privilege functions | Simple queries | `sqitch.checkit()` helper | Queries on `user_objects` |
| **Plan comment prefix** | `--` | `--` | `--` | `--` |

## Docker (`Dockerfile.sqitch`)

The official `sqitch/sqitch:latest` Docker image supports all engines.
Example Dockerfile (PostgreSQL shown; adjust the URI and client for your engine):

```dockerfile
FROM sqitch/sqitch:latest
WORKDIR /repo
COPY sqitch.conf /repo/
COPY sqitch.plan /repo/
COPY deploy/ /repo/deploy/
COPY revert/ /repo/revert/
COPY verify/ /repo/verify/
ENTRYPOINT ["sqitch"]
CMD ["deploy", "db:pg://user:pass@host:5432/dbname"]
```

Build & run:

```bash
docker build -f Dockerfile.sqitch -t my-migrations .
docker run --network host my-migrations deploy
docker run --network host my-migrations status
docker run --network host my-migrations verify
```

Using docker-compose to run migrations as a service alongside your app:

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: dbname
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d dbname"]
      interval: 5s
      retries: 10

  sqitch:
    build:
      context: migrations
      dockerfile: Dockerfile.sqitch
    depends_on:
      postgres:
        condition: service_healthy
    command: ["deploy", "db:pg://user:pass@postgres:5432/dbname"]

  sqitch_test:
    build:
      context: migrations
      dockerfile: Dockerfile.sqitch
    depends_on:
      postgres:
        condition: service_healthy
    command: ["deploy", "db:pg://user:pass@postgres:5432/dbname_test"]
```

## The Plan File (`sqitch.plan`)

Each line represents one change with dependencies bracketed:

```
%syntax-version=1.0.0
%project=myapp

initial_schema 2026-06-26T21:33:57Z Author <email> # Initial schema
change_name [dependency1 dependency2] 2026-06-27T10:00:00Z Author <email> # Description
@v1.0.0 2026-06-27T12:00:00Z Author <email> # Tag v1.0.0
```

- Changes are always appended to the end; never reorder or delete lines.
- Tags are inserted on their own line between changes.
- Dependencies are listed in brackets after the change name.
- Use `git` with a `.gitattributes` entry `sqitch.plan merge=union` to
  avoid merge conflicts when multiple branches append to the plan.

## Git Workflow for Parallel Branches

```bash
# In .gitattributes:
sqitch.plan merge=union

# Rebase a feature branch onto main:
git checkout feature
git rebase main
sqitch rebase   # reverts old + deploys new in correct order
```

## Best Practices

1. **Always identify the engine first** – read `sqitch.conf` before writing
   any SQL. SQL syntax, DDL transactionality, and verify patterns vary.
2. **Always write a verify script** – it is your safety net.
3. **Mark dependencies explicitly** with `--requires` in both `sqitch add`
   flags and as comments in deploy scripts.
4. **Tag before releasing** – tags enable `sqitch rework` and make rollbacks
   predictable.
5. **Use `--verify` on deploy** in development to catch mistakes early.
6. **One conceptual change per migration** – don't bundle unrelated DDL.
7. **Wrap in transactions where supported** – PostgreSQL, SQLite, and Oracle
   support transactional DDL (`BEGIN;`/`COMMIT;`). MySQL does not.
8. **Revert scripts mirror deploy** – drop/create in reverse dependency order.

## References

See `reference/links.md` for official Sqitch documentation links, including
engine-specific tutorials.
