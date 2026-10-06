# Alembic Migrations (async projects)

Current Alembic (1.20, Sept 2026) requires SQLAlchemy ≥ 2.0 and Python ≥ 3.10.

## Contents
1. Async `env.py`
2. Autogenerate: always review
3. What autogenerate does and doesn't detect
4. `alembic check` in CI
5. PostgreSQL ENUMs and data migrations

---

## 1. Async `env.py`

New project: `alembic init -t async migrations` (or `-t pyproject_async` to keep config in `pyproject.toml`). The generated `env.py` runs migrations on an async engine through `run_sync`:

```python
import asyncio

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

from myapp.models import Base

config = context.config
target_metadata = Base.metadata        # autogenerate compares against this

def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()

def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())
```
(The template also contains `run_migrations_offline()` for `--sql` mode; keep it.) Import every models module before reading `Base.metadata`, or autogenerate won't see those tables. Read the DB URL from the environment rather than committing it in `alembic.ini`.

**Sharing a connection programmatically** (e.g. running migrations from test setup): put an existing connection in `config.attributes["connection"]` and have `run_migrations_online()` call `do_run_migrations(connection)` when present, else `asyncio.run(run_async_migrations())` — see the Alembic cookbook "Programmatic API use (connection sharing) With Asyncio".

---

## 2. Autogenerate: always review

```bash
# WRONG — empty hand-written revision; drifts from the models
alembic revision -m "add is_active"      # then typing op.add_column(...) by hand

# CORRECT — autogenerate from metadata, then read the diff before applying
alembic revision --autogenerate -m "add user.is_active"
```

Autogenerate is explicitly "not intended to be perfect" — always read and fix the generated script.

```python
# WRONG — autogenerate emits drop + add for a rename → destroys the column's data
op.drop_column("user", "fullname")
op.add_column("user", sa.Column("full_name", sa.String()))

# CORRECT — rename preserves data
op.alter_column("user", "fullname", new_column_name="full_name")
```

---

## 3. What autogenerate does and doesn't detect

| Detects | Optional (off by default) | Cannot detect |
|---|---|---|
| Table add/remove | Server-default changes (`compare_server_default=True`) | Table renames (shows as drop + add) |
| Column add/remove | Named CHECK constraint add/remove (opt-in plugin `alembic.ext.checkconstraint_byname`, 1.19.2+) | Column renames (shows as drop + add) |
| Nullable changes | | Anonymously named constraints — name them (naming convention on `MetaData`) |
| Indexes, explicitly named unique constraints | | |
| Foreign keys | | |
| Column type changes (`compare_type` is on by default) | | |

Alembic 1.20 also renders a warning comment above any `op.drop_constraint()` whose name is `None` — another reason to configure a naming convention (see `models.md`).

---

## 4. `alembic check` in CI

```bash
alembic check    # fails if autogenerate would produce new operations
```
Runs the same comparison as `revision --autogenerate` without writing files — catches "changed a model, forgot the migration" before merge.

---

## 5. PostgreSQL ENUMs and data migrations

- Declare `pg.ENUM(..., name="my_enum", create_type=False)` on the model and let the migration own `CREATE TYPE` / `DROP TYPE` (e.g. `my_enum.create(op.get_bind(), checkfirst=True)` or `op.execute(...)`), so re-running doesn't hit `DuplicateObject`.
- Autogenerate doesn't track ENUM value changes; add values by hand (`op.execute("ALTER TYPE my_enum ADD VALUE 'c'")`) or use the third-party `alembic-postgresql-enum` extension.
- **Data migrations:** `op.execute(...)` / `op.get_bind()` in the migration body; keep large backfills in separate, batched scripts.
- `include_schemas=True` in `context.configure()` for multi-schema databases.
- Batch mode (`op.batch_alter_table`) is for SQLite's limited ALTER — not needed for PostgreSQL.
