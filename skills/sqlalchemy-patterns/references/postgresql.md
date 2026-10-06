# PostgreSQL-Specific Patterns

## Contents
1. Types (JSONB, ARRAY, INET, ENUM, UUID)
2. JSONB operations
3. Upsert — `INSERT ... ON CONFLICT`
4. RETURNING
5. Window functions and full-text search
6. Drivers: asyncpg / psycopg, PgBouncer
7. 2.1 named-type changes

---

## 1. Types

```python
import uuid
from uuid import uuid4

from sqlalchemy import JSON, String
from sqlalchemy.dialects import postgresql as pg

# WRONG — plain JSON (text storage, no GIN index, no containment operators)
data: Mapped[dict] = mapped_column(JSON, default=dict)

# CORRECT
id:     Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid4)   # Uuid → native UUID
data:   Mapped[dict]      = mapped_column(pg.JSONB, default=dict)            # always JSONB
tags:   Mapped[list[str]] = mapped_column(pg.ARRAY(String))
ip:     Mapped[str]       = mapped_column(pg.INET)
status: Mapped[str]       = mapped_column(pg.ENUM("a", "b", name="my_enum", create_type=False))
```
*JSONB is binary, GIN-indexable, and supports containment. `create_type=False` means no CREATE/DROP TYPE is emitted with the table — the Alembic migration owns the type (see `alembic.md`). `pg.UUID(as_uuid=True)` is the PG-specific equivalent of core `Uuid` — use `Uuid` unless you need PG-only behavior.*

---

## 2. JSONB operations

```python
Model.data["key"].astext            # ->> text value
Model.data.op("->")("key")          # -> json value
Model.data.contains({"k": "v"})     # @>  containment
Model.data.has_key("k")             # ?   key exists
Model.data.has_any(["a", "b"])      # ?|  any key exists
func.jsonb_set(Model.data, "{k}", '"v"')   # update nested key
```

---

## 3. Upsert — `INSERT ... ON CONFLICT`

Import `insert` from the PostgreSQL dialect; build the statement in two steps so `excluded` can refer back to it.

```python
from sqlalchemy.dialects.postgresql import insert as pg_insert

stmt = pg_insert(User).values([{"email": e, "name": n} for e, n in rows])
stmt = stmt.on_conflict_do_update(
    index_elements=[User.email],                              # the unique key
    set_={"name": stmt.excluded.name, "updated": func.now()}, # excluded = the proposed row
)
await session.execute(stmt)

# Ignore duplicates
await session.execute(
    pg_insert(User).values(rows_as_dicts).on_conflict_do_nothing(index_elements=[User.email])
)

# Get the upserted ORM objects back, refreshing any already in the session
users = (await session.scalars(
    stmt.returning(User), execution_options={"populate_existing": True}
)).all()
```
*Keys in `.values()` are ORM attribute names. `populate_existing` matters for upserts because returned rows may already be in the identity map with stale values.*

---

## 4. RETURNING

```python
stmt = pg_insert(User).values(email="a@example.test").returning(User.id, User.created)
row = (await session.execute(stmt)).one()
```
Bulk INSERT..RETURNING of ORM objects and order guarantees: `querying.md` § Bulk.

---

## 5. Window functions and full-text search

```python
func.row_number().over(partition_by=Order.user_id, order_by=Order.created.desc())
func.rank().over(order_by=Order.total.desc())
func.lag(Order.total).over(order_by=Order.created)
```

```python
stmt = select(Doc).where(
    func.to_tsvector("english", Doc.body).op("@@")(func.plainto_tsquery("english", q))
)
Index("ix_doc_fts", func.to_tsvector("english", Doc.body), postgresql_using="gin")
```

Common `func.*`: `func.now()`, `func.gen_random_uuid()`, `func.coalesce(col, default)`, `func.nullif(col, "")`, `func.array_agg(col)`, `func.string_agg(col, ", ")`.

---

## 6. Drivers: asyncpg / psycopg, PgBouncer

- `postgresql+asyncpg://...` — asyncpg.
- `postgresql+psycopg://...` with `create_async_engine` — psycopg 3 async (`postgresql+psycopg_async://` is the explicit form).
- **2.1:** the default PG driver (bare `postgresql://`) is psycopg 3, not psycopg2. Spell the driver explicitly so behavior doesn't change on upgrade.

**asyncpg behind PgBouncer** — use `NullPool` and unique prepared-statement names, and configure PgBouncer to `DISCARD` on release:
```python
from uuid import uuid4
from sqlalchemy.pool import NullPool

engine = create_async_engine(
    "postgresql+asyncpg://user:pw@pgbouncer-host/db",
    poolclass=NullPool,
    connect_args={"prepared_statement_name_func": lambda: f"__asyncpg_{uuid4()}__"},
)
```

**asyncpg + many ENUM types:** new connections may run an expensive type-introspection query; the SQLAlchemy docs suggest disabling JIT: `connect_args={"server_settings": {"jit": "off"}}`.

---

## 7. 2.1 named-type changes (ENUM / DOMAIN)

- Named types are associated with the `MetaData`, not a single `Table`, and inherit `MetaData(schema=...)` by default. Set `Enum(..., schema="x")` explicitly if the type must live in a table's schema.
- `metadata.create_all()` / `Table.create()` create needed types; `Table.drop()` no longer drops them; `metadata.drop_all()` drops them after the tables.
- `Enum.inherit_schema` is deprecated.
- `create_all(checkfirst=CheckFirst.TABLES | CheckFirst.TYPES)` gives fine-grained existence checks.
