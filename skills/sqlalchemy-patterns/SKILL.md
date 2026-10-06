---
name: sqlalchemy-patterns
description: >-
  Comprehensive SQLAlchemy 2.0+ async + PostgreSQL patterns — declarative
  models, relationships, type-safe Mapped[ columns, querying, eager loading,
  transactions, and Alembic migrations. Use when working with SQLAlchemy; to
  write a model, declarative model, or ORM model; add a column, mapped_column,
  or Mapped[ annotation; define a relationship, foreign key, or index on a
  table; choose selectinload, joinedload, or load_only; configure an async
  session or call session.execute; fix N+1 queries; do a bulk insert or upsert;
  use JSONB or a PostgreSQL type; count rows; write a migration model; or write
  any SQLAlchemy query. Not for SQLAlchemy 1.x, non-async (sync) codebases, or
  non-PostgreSQL databases (MySQL, SQLite, etc.).
---

# SQLAlchemy 2.0+ Patterns (Async · PostgreSQL)

Rules for writing SQLAlchemy 2.0 / 2.1 code where **PostgreSQL is the database and async is the execution model**. Everything here is 2.0-style — no legacy `Column()` class attributes, `session.query()`, or `declarative_base()`.

> Project-agnostic: examples use generic names (`User`, `Order`). Adapt names to the project; never copy example session names or pool numbers as if they were rules.

**Versions:** works on SQLAlchemy 2.0 and 2.1 (current release line). On 2.1: Python ≥ 3.11, install `sqlalchemy[asyncio]` (greenlet is no longer pulled in by default), and always name the driver in the URL (`postgresql+asyncpg://` / `postgresql+psycopg://`). Upgrade notes: `references/migration-2.1.md`.

---

## Quick Reference Cheatsheet

| Rule | Do this |
|---|---|
| Base class | `class Base(AsyncAttrs, DeclarativeBase)` — never `declarative_base()` |
| Columns | `mapped_column()` + `Mapped[T]` — never bare `Column()` on a mapped class |
| Nullable | `Mapped[str]` = NOT NULL · `Mapped[str \| None]` = NULL |
| UUID PK | `Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid4)` (maps to `Uuid` automatically) |
| Timestamps | `type_annotation_map = {datetime.datetime: DateTime(timezone=True)}` on Base; `server_default=func.now()` |
| `updated` column in async | `onupdate=func.now(), server_onupdate=FetchedValue()` + `__mapper_args__ = {"eager_defaults": True}` |
| Relationship | `Mapped[list["X"]]` / `Mapped["X"]` + `back_populates` — never `backref` |
| Cascade in async | `"save-update, merge, expunge, delete, delete-orphan"` — not `"all"` |
| Huge collection | `WriteOnlyMapped["X"]` — never `DynamicMapped` (not async-compatible) |
| FK | on the **many** side; `ForeignKey("t.id", ondelete="CASCADE")` |
| Sessionmaker | `async_sessionmaker(engine, expire_on_commit=False)` |
| Query | `select(Model)` + `await session.execute / scalars / scalar / get` |
| List of entities | `(await session.scalars(stmt)).all()` |
| One or none | `(await session.execute(stmt)).scalar_one_or_none()` |
| Relationship access | `selectinload` (collections) / `joinedload` (scalars) on the query |
| `joinedload` on a collection | add `.unique()` to the result |
| Eager load + filter | `selectinload(User.roles.and_(Role.active))` — not `.where()` |
| List endpoint | `load_only(...)` with only the columns the response needs |
| N+1 | never query inside a loop — one `WHERE id IN (...)` |
| Bulk insert | `await session.execute(insert(Model), [{...}, ...])`; `.returning(Model)` via `session.scalars` |
| Count | `await session.scalar(select(func.count()).select_from(Model))` |
| NULL test | `col.is_(None)` / `col.is_not(None)` — never `== None` |
| Upsert | `pg_insert(Model)...on_conflict_do_update(index_elements=[...], set_={...})` |
| JSON column | `Mapped[dict] = mapped_column(JSONB, default=dict)` — JSONB, never JSON |
| Commit lives in | the service / unit-of-work layer — never a repository helper |
| Concurrency | one `AsyncSession` per task — never shared across `asyncio.gather` |

---

## Pre-Query Checklist (run before writing ANY DB function)

1. **Read-only?** Use the read/replica session if the project exposes one.
2. **Returns a list?** Add `load_only(...)` with only the columns the response schema needs.
3. **Touches a relationship?** Add an explicit loader on the outer query — `selectinload` for collections, `joinedload` for scalars. Lazy loading in async raises `MissingGreenlet`.
4. **Any query inside a loop?** Replace with one `WHERE col.in_([...])`.
5. **Counting?** `select(func.count())`, never `len(... .all())`.
6. **Async correctness?** `select()` + `await session.*`; `expire_on_commit=False`; no attribute access that could trigger IO after commit or after an UPDATE flush.
7. **Filtering on NULL?** `is_()` / `is_not()`.
8. **Bulk write?** `add_all()` or Core `insert/update/delete` with a list of dicts — never `add()` in a loop.
9. **Insert that may collide?** PostgreSQL `insert` + `on_conflict_do_update` / `do_nothing`.
10. **Case-insensitive match?** `ilike()` or `func.lower(col) == value.lower()` (with a matching functional index).
11. **Where does `commit()` live?** Service layer. Repository functions read / stage / flush only.

---

## Decision Guide

**Which loader?**

| You will access… | Use |
|---|---|
| a collection (one-to-many, many-to-many) | `selectinload(Parent.children)` |
| a scalar (many-to-one, one-to-one) | `joinedload(Child.parent)` (`innerjoin=True` if FK NOT NULL) |
| a collection, filtered on the related table in WHERE | explicit `.join()` + `contains_eager()` |
| a subset of a collection | `selectinload(Parent.children.and_(...))` |
| a huge collection | `WriteOnlyMapped` + `parent.children.select()` |
| one attribute, once, no loader planned | `await obj.awaitable_attrs.rel` or `await session.refresh(obj, ["rel"])` |
| nothing beyond what you loaded (tests) | add `raiseload("*")` to fail loudly |

**Which write path?**

| Situation | Use |
|---|---|
| A few objects; need events, relationships, cascades | `session.add()` / `add_all()` + flush |
| Many rows from dicts | `session.execute(insert(Model), rows)` |
| Many rows and you need them back | `session.scalars(insert(Model).returning(Model), rows)` |
| Rows may already exist | `pg_insert(...).on_conflict_do_update / do_nothing` |
| Update many rows, same values | `update(Model).where(...).values(...)` |
| Update many rows, different values per PK | `session.execute(update(Model), [{"id": ..., ...}, ...])` |

**Which transaction style?** Service function owns the boundary: `async with async_session.begin() as session:` (commit on success, rollback on exception). Repository helpers take a `session`, stage work, and `flush()` if they need generated PKs. Use `begin_nested()` for a savepoint that may fail independently.

---

## Canonical Setup

```python
import datetime
import uuid
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, MetaData, func, select
from sqlalchemy.ext.asyncio import AsyncAttrs, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, selectinload

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

class Base(AsyncAttrs, DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
    type_annotation_map = {datetime.datetime: DateTime(timezone=True)}

class User(Base):
    __tablename__ = "user"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(unique=True)
    full_name: Mapped[str | None]
    created: Mapped[datetime.datetime] = mapped_column(server_default=func.now())
    orders: Mapped[list["Order"]] = relationship(back_populates="user")

class Order(Base):
    __tablename__ = "order"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("user.id", ondelete="CASCADE"))
    user: Mapped[User] = relationship(back_populates="orders")

engine = create_async_engine("postgresql+asyncpg://user:pw@host/db", pool_pre_ping=True)
async_session = async_sessionmaker(engine, expire_on_commit=False)

async def users_with_orders(limit: int) -> list[User]:
    async with async_session() as session:
        stmt = select(User).options(selectinload(User.orders)).order_by(User.created).limit(limit)
        return list((await session.scalars(stmt)).all())
```
*Why each piece: the naming convention keeps Alembic constraint names stable; the `datetime` map makes timestamps `TIMESTAMPTZ` (the default is naive `TIMESTAMP`); `expire_on_commit=False` keeps loaded attributes readable after commit; `selectinload` loads the collection inside the awaited query so nothing lazy-loads later.*

---

## Common Mistakes

| Mistake | Why it breaks | Fix |
|---|---|---|
| `async_sessionmaker(engine)` with default `expire_on_commit=True` | Attributes expire on commit; next access is implicit IO → `MissingGreenlet` | `expire_on_commit=False` |
| Accessing `obj.updated` after an UPDATE flush | `onupdate` values aren't fetched back; attribute is expired | `server_onupdate=FetchedValue()` + `eager_defaults=True`, or `await session.refresh(obj, ["updated"])` |
| `cascade="all, delete-orphan"` in async | `all` includes `refresh-expire`, which expires related objects aggressively | `"save-update, merge, expunge, delete, delete-orphan"` |
| `DynamicMapped` / `lazy="dynamic"` | Not compatible with asyncio | `WriteOnlyMapped` |
| `subqueryload` | Legacy; superseded | `selectinload` |
| `joinedload(collection)` without `.unique()` | ORM raises; rows are multiplied by the JOIN | `.unique()` or `selectinload` |
| `selectinload(X.rel).where(...)` | Loader options have no `.where()` | `selectinload(X.rel.and_(...))` |
| `Mapped[datetime]` assumed tz-aware | Default type map → `TIMESTAMP WITHOUT TIME ZONE` | `type_annotation_map = {datetime.datetime: DateTime(timezone=True)}` |
| `default={}` / `default=[]` | One mutable object shared by every row | `default=dict` / `default=list` |
| One `AsyncSession` shared by `asyncio.gather` tasks | Session is a single stateful transaction | One session per task |
| `@event.listens_for(async_engine, "connect")` | Events attach to sync objects; the `AsyncEngine` proxies a sync `Engine` | `@event.listens_for(engine.sync_engine, "connect")` |
| `async def` event handler | Event handlers are synchronous | Plain `def`; no awaits, no lazy loads |
| Bare `postgresql://` URL | Driver changes between 2.0 (psycopg2) and 2.1 (psycopg 3) | Name the driver explicitly |
| `session.commit()` inside a repository helper | Caller can't roll back the whole unit of work | Commit in the service layer |
| Mocked session in tests | Tests your mocks, not your SQL | Real DB + outer transaction + `join_transaction_mode="create_savepoint"` |
| `TypeDecorator` without `cache_ok = True` | Warns and disables statement caching for that type | Set `cache_ok = True` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `MissingGreenlet: greenlet_spawn has not been called` | Lazy load, deferred column, or expired attribute accessed in async | Eager loader; `expire_on_commit=False`; `FetchedValue` for `onupdate`; `awaitable_attrs` |
| Async extension fails because `greenlet` is missing (2.1) | Installed `sqlalchemy` without the extra | `pip install "sqlalchemy[asyncio]"` |
| `InvalidRequestError` about joined eager load needing unique | `joinedload` on a collection | `.unique()` or `selectinload` |
| `selectinload(...).where(...)` AttributeError | Loader options have no `.where()` | `.and_()` on the relationship |
| `SAWarning: TypeDecorator ... will not produce a cache key` | `cache_ok` unset | `cache_ok = True` |
| `DetachedInstanceError` | Attribute access after the session closed | Load what you need inside the session; `expire_on_commit=False` |
| `AmbiguousColumnError` from `filter_by` (2.1) | Name exists on more than one joined entity | `.where(Entity.col == v)` |
| Enum `DuplicateObject` in a migration | ENUM type created twice | `create_type=False`; migration owns `CREATE TYPE` |
| Errors after idle / DB restart | Stale pooled connection | `pool_pre_ping=True` + `pool_recycle` |
| asyncpg `prepared statement ... already exists` behind PgBouncer | Statement-name collisions | `NullPool` + `prepared_statement_name_func` (see `references/postgresql.md`) |

---

## References — read the one you need

- **Read `references/models.md`** when declaring or changing a model: defaults (`default` / `insert_default` / `server_default` / `onupdate`), relationships and cascades, many-to-many, self-referential, `WriteOnlyMapped`, `type_annotation_map`, `TypeDecorator`, indexes and constraints, hybrids, `column_property`.
- **Read `references/loading.md`** when choosing or debugging a loader: `selectinload` vs `joinedload`, `.unique()`, `.and_()` filters, `with_loader_criteria`, `contains_eager`, `raiseload`, `load_only` / `defer`.
- **Read `references/querying.md`** when writing SELECTs, filters, bulk INSERT/UPDATE/DELETE (incl. RETURNING and order guarantees), counts, aggregates, subqueries, EXISTS, or recursive CTEs.
- **Read `references/async-sessions.md`** when setting up the engine or sessions, deciding transaction boundaries, using `AsyncAttrs` / `refresh` / `run_sync`, running concurrent tasks, attaching events, or tuning the pool.
- **Read `references/postgresql.md`** for JSONB / ARRAY / ENUM / UUID types, JSONB operators, upserts, RETURNING, window functions, full-text search, asyncpg vs psycopg, and PgBouncer.
- **Read `references/testing.md`** when writing tests or fixtures that touch the database.
- **Read `references/alembic.md`** when creating or reviewing migrations: async `env.py`, autogenerate limits, `alembic check`, ENUMs, data migrations.
- **Read `references/migration-2.1.md`** when upgrading from 2.0 to 2.1 or when behavior differs between the two.

---

## Keeping This Skill Current

- Found a pattern or error not covered? Add it to the relevant reference file (or the Troubleshooting table) and open a PR to the source repo.
- Upgrading? Check the changelogs: SQLAlchemy `https://docs.sqlalchemy.org/en/21/changelog/` and Alembic `https://alembic.sqlalchemy.org/en/latest/changelog.html`.
- Every API claim should be traceable to the official docs; append a dated line below for each update.

### Changelog
- 2026-06-17 — Initial version, verified against SQLAlchemy 2.0 docs (2.0.51).
- 2026-06-28 — Packaged into the `omar-skills` marketplace; install-agnostic wording; removed a contradictory `IN (subquery)` example.
- 2026-10-07 — Re-verified against SQLAlchemy 2.1 docs (2.1.3) and Alembic 1.20. Split into `SKILL.md` + `references/`. Added decision guide, common-mistakes table, 2.1 upgrade notes, async Alembic `env.py`, savepoint-based test fixture. Fixed: tz-naive timestamp claim, `onupdate` expiry in async, `"all"` cascade in async, async event targets, `subqueryload` guidance, `DynamicMapped` vs `WriteOnlyMapped`.
