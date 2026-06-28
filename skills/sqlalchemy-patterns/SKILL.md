---
name: sqlalchemy-patterns
description: Comprehensive SQLAlchemy 2.0+ async + PostgreSQL patterns — declarative models, relationships, type-safe Mapped[ columns, querying, eager loading, transactions, and Alembic migrations. Use when working with SQLAlchemy; to write a model, declarative model, or ORM model; add a column, mapped_column, or Mapped[ annotation; define a relationship, foreign key, or index on a table; choose selectinload, joinedload, or load_only; configure an async session or call session.execute; fix N+1 queries; do a bulk insert or upsert; use JSONB or a PostgreSQL type; count rows; write a migration model; or write any SQLAlchemy query.
---

# SQLAlchemy 2.0+ Patterns (Async · PostgreSQL)

The definitive reference for writing SQLAlchemy 2.0+ code. PostgreSQL is the target database. **Async is the default execution model.** Every pattern here is 2.0-style — zero legacy `Column()` / `session.query()` / `declarative_base()` patterns. When you write any model, query, or migration, follow these rules exactly.

> This is a **global, project-agnostic** skill. Examples use generic names (`User`, `Order`). Adapt names to the project, never copy project-specific session names or pool numbers from examples as if they were rules.

---

## Quick Reference Cheatsheet (scan in 30 seconds)

| Rule | Do this |
|---|---|
| Base class | `class Base(DeclarativeBase)` — never `declarative_base()` |
| Columns | `mapped_column()` + `Mapped[T]` — never bare `Column()` |
| Nullable | `Mapped[str]` = NOT NULL · `Mapped[str \| None]` = NULL |
| PK (uuid) | `Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)` |
| Created/updated | `server_default=func.now()`; updated adds `onupdate=...` |
| Relationship | `Mapped[list["X"]]` (collection) / `Mapped["X"]` (scalar) + `back_populates` — never `backref` |
| FK | always on the **many** side; `ForeignKey("t.id", ondelete="CASCADE")` |
| Async sessionmaker | `async_sessionmaker(engine, expire_on_commit=False)` — `expire_on_commit=False` is required |
| Query | `select(Model)` + `await session.execute(...)` — never `session.query()` in async |
| Get list of entities | `(await session.scalars(stmt)).all()` |
| Get one or none | `(await session.execute(stmt)).scalar_one_or_none()` |
| Relationship access | declare `selectinload` (collections) / `joinedload` (scalars) — lazy load = `MissingGreenlet` in async |
| `joinedload` collection | add `.unique()` to the result — mandatory |
| Eager load + filter | `selectinload(User.roles.and_(Role.active))` — **NOT** `.where()` |
| List endpoint | always add `load_only(...)` with only the columns the response needs |
| N+1 | never query inside a loop — `WHERE id IN (...)` once |
| Bulk insert | `await session.execute(insert(Model), [{...}, ...])` — never `add()` in a loop |
| Count | `await session.scalar(select(func.count()).select_from(Model))` — never `len(.all())` |
| NULL test | `col.is_(None)` / `col.is_not(None)` — never `== None` |
| Upsert | `pg_insert(Model)...on_conflict_do_update(index_elements=[...], set_={...})` |
| JSON column | `Mapped[dict] = mapped_column(JSONB, default=dict)` — JSONB, never JSON |
| Commit lives in | the service/unit-of-work layer — never in a repository helper |

---

## Pre-Query Checklist (run before writing ANY DB function)

1. **Read-only?** Use the read/replica session if the project exposes one; otherwise the standard session.
2. **Returns a list?** Add `load_only(...)` selecting only the columns the response schema needs.
3. **Touches a relationship?** Add an explicit loader on the outer query — `selectinload` for collections, `joinedload` for scalars. Never lazy-load in async.
4. **Any query inside a loop?** Replace with one `WHERE col.in_([...])`. Never call `session.get()` / `session.execute()` per iteration.
5. **Counting?** Use `select(func.count())`. Never `len((await session.scalars(...)).all())`.
6. **Async?** `select()` + `await session.execute/scalars`. Never `session.query()`. Confirm `expire_on_commit=False`.
7. **Filtering on NULL?** `is_()` / `is_not()`. Never `== None`.
8. **Bulk write?** `add_all()` or Core `insert/update/delete`. Never `add()` in a loop.
9. **Insert that may collide?** PostgreSQL `insert` + `on_conflict_do_update`.
10. **Case-insensitive match?** `ilike()` or `func.lower(col) == value.lower()`.
11. **Where does `commit()` live?** Service layer. Repository functions read/stage only.

---

## Section 1 — Declarative Models (2.0 style)

**Rule: subclass `DeclarativeBase`.** `declarative_base()` is the legacy 1.x factory; the class form gives full PEP 484 typing with no plugins.

```python
# WRONG — legacy
from sqlalchemy.orm import declarative_base
Base = declarative_base()
class User(Base):
    id = Column(Integer, primary_key=True)   # untyped, no Mapped[]

# CORRECT — 2.0
import uuid
from uuid import uuid4
from datetime import datetime
from sqlalchemy import MetaData, Uuid, func, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Constraint naming convention — so Alembic generates stable, predictable names.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
```
*Why the naming convention: unnamed constraints get random DB-assigned names; autogenerated migrations then can't reliably drop/alter them.*

**Rule: every column is `mapped_column()` + `Mapped[T]`.** `mapped_column()` reads the annotation for type and nullability. Bare `Column()` carries no ORM typing.

**Nullability is inferred from the annotation — do not also pass `nullable=`:**

```python
class User(Base):
    __tablename__ = "user"
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    email: Mapped[str]              # NOT NULL
    full_name: Mapped[str | None]   # NULL
    is_active: Mapped[bool] = mapped_column(server_default=text("true"))
```
*Why: `Mapped[str]` → NOT NULL, `Mapped[str | None]` → NULL. The annotation is the single source of truth.*

**Server defaults vs Python defaults — `default=` runs in Python at INSERT; `server_default=` is emitted as DDL and runs in the database.**

```python
# WRONG — created_at set by the app clock, drifts between app servers, naive datetime
created: Mapped[datetime] = mapped_column(default=datetime.utcnow)

# CORRECT — database clock, single source of truth
created: Mapped[datetime] = mapped_column(server_default=func.now())
updated: Mapped[datetime] = mapped_column(
    server_default=func.now(),
    onupdate=func.now(),   # recomputed on every UPDATE flush
)
```
*Why: `func.now()` uses the DB clock — consistent across processes and timezone-correct (`TIMESTAMP`). `onupdate=` fires on UPDATE only.*

**Integer PK:** `id: Mapped[int] = mapped_column(primary_key=True)` (autoincrement is implicit). **UUID PK:** use the core `Uuid` type (portable; emits native `UUID` on PostgreSQL) with `default=uuid4`.

**Abstract base for shared columns** — use a mixin / `__abstract__` base, not copy-paste:

```python
class TimestampMixin:
    created: Mapped[datetime] = mapped_column(server_default=func.now())
    updated: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())

class User(TimestampMixin, Base):
    __tablename__ = "user"
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
```

**`__table_args__`** — tuple for constraints/indexes; dict for options; tuple-with-trailing-dict for both:
```python
__table_args__ = (
    UniqueConstraint("email", name="uq_user_email"),
    Index("ix_user_active", "is_active"),
    {"comment": "Application users"},   # dict MUST be last
)
```

---

## Section 2 — Relationships

**Rule: type the relationship with `Mapped[...]` and pair both sides with `back_populates`. Never use `backref`** (it hides the reverse side from type checkers and configures it implicitly).

```python
# WRONG — backref (untyped reverse side) and FK on the one side
class Parent(Base):
    __tablename__ = "parent"
    id: Mapped[int] = mapped_column(primary_key=True)
    child_id: Mapped[int] = mapped_column(ForeignKey("child.id"))   # FK on the wrong side
    children = relationship("Child", backref="parent")              # backref, no Mapped[]

# CORRECT — one-to-many. FK lives on the MANY (child) side.
class Parent(Base):
    __tablename__ = "parent"
    id: Mapped[int] = mapped_column(primary_key=True)
    children: Mapped[list["Child"]] = relationship(back_populates="parent")  # collection

class Child(Base):
    __tablename__ = "child"
    id: Mapped[int] = mapped_column(primary_key=True)
    parent_id: Mapped[int] = mapped_column(ForeignKey("parent.id", ondelete="CASCADE"))
    parent: Mapped["Parent"] = relationship(back_populates="children")       # scalar
```
*Why FK on the many side: a child has one parent; the parent's "many children" is derived from the children's FK.*

**`cascade="all, delete-orphan"`** — deletes children when the parent is deleted AND when a child is removed from the collection. Pair it with a DB-side `ondelete="CASCADE"` + `passive_deletes=True` so the database does the bulk delete:
```python
children: Mapped[list["Child"]] = relationship(
    back_populates="parent", cascade="all, delete-orphan", passive_deletes=True
)
```
*Why `passive_deletes=True`: without it, the ORM SELECTs every child then DELETEs them one by one. With it, the DB `ON DELETE CASCADE` handles them in one statement.*

**Many-to-many (no extra columns) — `secondary=` with a `Table`:**
```python
user_role = Table(
    "user_role", Base.metadata,
    Column("user_id", ForeignKey("user.id", ondelete="CASCADE"), primary_key=True),
    Column("role_id", ForeignKey("role.id", ondelete="CASCADE"), primary_key=True),
)
class User(Base):
    roles: Mapped[list["Role"]] = relationship(secondary=user_role, back_populates="users")
```

**Many-to-many WITH extra columns — association object** (map the join table as a class):
```python
class UserRole(Base):                              # the association row
    __tablename__ = "user_role"
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), primary_key=True)
    role_id: Mapped[int] = mapped_column(ForeignKey("role.id"), primary_key=True)
    granted_at: Mapped[datetime] = mapped_column(server_default=func.now())
    user: Mapped["User"] = relationship(back_populates="role_links")
    role: Mapped["Role"] = relationship(back_populates="user_links")
```
*Why: `secondary=` can't store columns on the join. The moment the link needs its own data, use an association object.*

**`viewonly=True`** — read-only relationship (computed join, never flushed). Use for derived collections; mutations to it are silently ignored, so never write through a `viewonly` relationship.

**Self-referential (trees)** — set `remote_side` to the PK:
```python
class Node(Base):
    __tablename__ = "node"
    id: Mapped[int] = mapped_column(primary_key=True)
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("node.id"))
    children: Mapped[list["Node"]] = relationship(back_populates="parent")
    parent: Mapped["Node | None"] = relationship(back_populates="children", remote_side=[id])
```

**Non-FK join — `primaryjoin`** with `foreign()`/`remote()` markers when there is no real ForeignKey (e.g. IP-range containment). Always `viewonly=True` for these.

**Catch accidental lazy loads — set `lazy="raise_on_sql"` on relationships you always eager-load.** It raises only when a load would emit SQL, surfacing missing loader options in tests before they hit production as `MissingGreenlet`.

---

## Section 3 — Type Safety with `Mapped[]`

**Rule: every column is typed; mypy/pyright understand `Mapped[T]` natively in 2.0 — no stubs.**

```python
# WRONG — untyped column (no Mapped[T]) and a shared mutable default
class Account(Base):
    id = mapped_column(Integer, primary_key=True)   # no Mapped[] → no type checking
    meta: Mapped[dict] = mapped_column(JSONB, default={})   # {} shared across ALL rows

# CORRECT
import enum
import uuid
from sqlalchemy import Enum, String, Uuid
from sqlalchemy.dialects.postgresql import ARRAY, JSONB

class Status(enum.Enum):
    ACTIVE = "active"
    BANNED = "banned"

class Account(Base):
    __tablename__ = "account"
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    status: Mapped[Status] = mapped_column(Enum(Status, name="account_status"))
    tags: Mapped[list[str]] = mapped_column(ARRAY(String))
    meta: Mapped[dict] = mapped_column(JSONB, default=dict)   # default=dict → fresh {} per row
```
*Why `default=dict` (not `default={}`): a literal `{}` is shared across all instances — a classic mutable-default bug.*

**`type_annotation_map` — map a Python type to a SQL type once, project-wide:**
```python
from typing import Annotated
from sqlalchemy.orm import registry

str_255 = Annotated[str, 255]

class Base(DeclarativeBase):
    registry = registry(type_annotation_map={str_255: String(255), dict: JSONB})

class User(Base):
    name: Mapped[str_255]   # → String(255)
    meta: Mapped[dict]      # → JSONB
```

**Custom domain type — `TypeDecorator` (always set `cache_ok`):**
```python
from sqlalchemy import types

class LowerString(types.TypeDecorator):
    impl = types.String
    cache_ok = True   # REQUIRED — unset disables statement caching and warns
    def process_bind_param(self, value, dialect):
        return value.lower() if value is not None else value
```
*Why `cache_ok = True`: SQLAlchemy 2.0 caches compiled statements keyed by type. An unset `cache_ok` emits a warning and silently disables caching for every statement using the type — a real perf regression.*

**`column_property()` for a read-only computed column** — see Section 14.

---

## Section 4 — Async Session Lifecycle

**Rule: `async_sessionmaker(..., expire_on_commit=False)`.** This is non-negotiable in async.

```python
# WRONG — default expire_on_commit=True
async_session = async_sessionmaker(engine)
async with async_session() as s:
    user = await s.get(User, uid)
    await s.commit()
    return user.email   # 💥 MissingGreenlet — attribute expired, reload needs IO

# CORRECT
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

engine = create_async_engine(
    "postgresql+asyncpg://user:pw@host/db",
    pool_pre_ping=True,     # detect dead connections before use
    echo=False,             # never True in production — logs every statement
)
async_session = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
```
*Why `expire_on_commit=False`: after commit, the default expires all attributes; the next attribute access triggers a synchronous reload, which has no greenlet in async → `MissingGreenlet`. Disabling it keeps loaded data usable after commit.*

**Session scope — always a context manager. Two transaction styles:**
```python
# Auto-commit on success, auto-rollback on exception:
async with async_session() as session, session.begin():
    session.add(obj)
# (no explicit commit — begin() commits at block exit)

# Manual control:
async with async_session() as session:
    session.add(obj)
    await session.commit()
```
*Why `async with`: guarantees the connection returns to the pool even on exception. Manual `close()` leaks on error paths.*

**Read replica — two engines, two sessionmakers.** Route read-only handlers to the replica sessionmaker, writes to the primary. (The exact dependency/session names are project-specific — use whatever the project exposes.)

**`session.get(Model, pk)`** checks the identity map first and emits a SELECT only on a miss — the right tool for a single PK lookup. **Never `session.query()` in async** — it's the legacy sync API and unsupported on `AsyncSession`.

**Need one lazy attribute without an upfront loader?** Use `AsyncAttrs` (2.0.13+): `class Base(AsyncAttrs, DeclarativeBase): ...` then `await obj.awaitable_attrs.children`. Prefer eager loaders for anything in a hot path.

**`AsyncSession` is NOT concurrency-safe** — never share one session across `asyncio.gather` tasks. One session per task.

**`run_sync()`** — only for sync-only operations like DDL: `await conn.run_sync(Base.metadata.create_all)`.

---

## Section 5 — Querying: Complete SELECT Guide

```python
from sqlalchemy import select, and_, or_, not_, nulls_last

# Whole entities → list[Model]
stmt = select(User).where(User.is_active.is_(True)).order_by(User.created.desc())
users = (await session.scalars(stmt)).all()

# Specific columns → list[Row]
stmt = select(User.id, User.email)
rows = (await session.execute(stmt)).all()   # each row: row.id, row.email
```

**WHERE composition:** multiple `.where(a, b)` args or `and_(a, b)` = AND; `or_(...)`; `not_(...)` / `~`.

**Ordering:** `User.col.desc()`, `User.col.asc()`, `nulls_last(User.col)`. **Pagination:** `.limit(n).offset(m)`. **Distinct:** `.distinct()`, or PostgreSQL `DISTINCT ON`: `select(User).distinct(User.email)`.

**Terminal methods — picking wrong returns the wrong shape:**

| Call | Returns |
|---|---|
| `(await session.scalars(stmt)).all()` | `list[Model]` (ORM objects) |
| `await session.scalar(stmt)` | first column of first row, or `None` |
| `(await session.execute(stmt)).scalar_one()` | exactly one value; raises if 0 or >1 |
| `(await session.execute(stmt)).scalar_one_or_none()` | one or `None`; raises if >1 |
| `(await session.execute(stmt)).first()` | first `Row` or `None` |
| `(await session.execute(stmt)).all()` | `list[Row]` (tuples) |

*Why `scalar_one_or_none()` for "fetch by unique key": it asserts uniqueness — a duplicate raises instead of silently returning the first.*

**Filtering operators:**
```python
# WRONG — Python truthiness / == on NULL, and filter_by for a complex predicate
select(User).where(User.deleted_at == None)        # linters flag this; fragile
select(User).filter_by(age > 18)                   # filter_by takes kwargs only → TypeError

# CORRECT
select(User).where(User.deleted_at.is_(None))      # emits IS NULL
select(User).where(User.age > 18)                  # use .where() for anything but simple equality

User.id.in_(ids)                       # IN
User.id.not_in(ids)                    # NOT IN
User.email.ilike("%@gmail.com")        # case-insensitive LIKE
User.age.between(18, 65)
User.deleted_at.is_(None)              # IS NULL  — NEVER == None
User.deleted_at.is_not(None)           # IS NOT NULL
func.lower(User.email) == email.lower()  # case-insensitive equality

from sqlalchemy import exists
stmt = select(exists().where(User.email == email))   # → await session.scalar(stmt) → bool
```
*Why `is_(None)` not `== None`: `== None` works by luck via operator overloading but linters flag it and it breaks on some expressions. `is_()` always emits `IS NULL`.*

---

## Section 6 — Relationship Loading (Mandatory in Async)

**This is the most important section. In async, accessing an unloaded relationship raises `MissingGreenlet` and kills the request.** Every relationship you touch must have an explicit loader on the outer query.

```python
from sqlalchemy.orm import selectinload, joinedload, raiseload, contains_eager

# WRONG — lazy load in async
users = (await session.scalars(select(User))).all()
for u in users:
    print(u.roles)   # 💥 MissingGreenlet

# CORRECT — collection → selectinload (second IN query)
stmt = select(User).options(selectinload(User.roles))
users = (await session.scalars(stmt)).all()

# CORRECT — scalar (many-to-one) → joinedload (LEFT OUTER JOIN, same query)
stmt = select(Order).options(joinedload(Order.customer))
orders = (await session.scalars(stmt)).all()
```

**Strategy choice:**
- **`selectinload(Model.rel)`** — collections (one-to-many, many-to-many). Emits one extra `WHERE IN` query. *Why: avoids the row-multiplication a JOIN causes on collections.*
- **`joinedload(Model.rel)`** — scalars (many-to-one, one-to-one). Adds a `LEFT OUTER JOIN`. Use `joinedload(Order.customer, innerjoin=True)` when the FK is NOT NULL.
- **`subqueryload` / `lazyload`** — never in async.
- **`raiseload("*")`** — add in development/tests to turn any accidental lazy load into an immediate error.

**`joinedload` on a collection requires `.unique()`** on the result — otherwise the JOIN's duplicate rows produce duplicate parents (and 2.0 raises):
```python
stmt = select(User).options(joinedload(User.roles))   # collection via JOIN
users = (await session.scalars(stmt)).unique().all()  # .unique() MANDATORY
```
(Prefer `selectinload` for collections — no `.unique()` needed.)

**Nesting:**
```python
select(User).options(selectinload(User.roles).selectinload(Role.permissions))
```

**Eager load WITH a filter — use `relationship.and_()`, NOT `.where()`:**
```python
# WRONG — Load options have no .where(); this is invalid syntax
select(User).options(selectinload(User.roles).where(Role.is_active == True))

# CORRECT — put the criteria inside the relationship attribute
select(User).options(selectinload(User.roles.and_(Role.is_active == True)))
```
*Why: the criteria attaches to the relationship's join condition. `.and_()` works identically across `selectinload`/`joinedload`/`lazyload`.*

**Global per-entity criteria — `with_loader_criteria()`** (applies everywhere that entity loads, including nested loads — ideal for soft-delete):
```python
from sqlalchemy.orm import with_loader_criteria
select(User).options(
    selectinload(User.roles),
    with_loader_criteria(Role, lambda cls: cls.deleted_at.is_(None)),
)
```

**`contains_eager(Model.rel)`** — when you've already written an explicit `.join()` and want it to populate the relationship (e.g. to filter on the joined table):
```python
stmt = (select(User).join(User.roles)
        .where(Role.name == "admin")
        .options(contains_eager(User.roles)))
```

---

## Section 7 — Partial Loading: `load_only` and `defer`

**Rule: every list endpoint uses `load_only()` with only the columns the response schema returns.** Large tables have heavy columns (blobs, JSONB, text) you don't need in a list view.

```python
from sqlalchemy.orm import load_only, defer, undefer

# WRONG — list endpoint pulls every column, including heavy text/JSONB/blob columns
stmt = select(User)

# CORRECT — list view fetches only what the response needs
stmt = select(User).options(load_only(User.id, User.email, User.is_active, User.created))
```
*Why: `SELECT *` on a wide table moves megabytes per page you immediately discard.*

**`defer(col)`** — exclude one heavy column, load it lazily only if accessed. **`undefer(col)`** — force-load a column deferred at the mapping level.

**Combine column + relationship loaders in one `.options()`:**
```python
stmt = select(User).options(
    load_only(User.id, User.email),
    selectinload(User.roles).load_only(Role.id, Role.name),
)
```

**Raise instead of lazy-loading a column** — `load_only(..., raiseload=True)` (2.0) whitelists columns and raises on access to any other; `defer(col, raiseload=True)` (1.4) raises on access to that one column. Use to catch unintended column loads in tests.

---

## Section 8 — N+1 Elimination & Batch Patterns

**N+1 = one query to get N rows, then one query per row inside a loop. Never do this.**

```python
# WRONG — N+1 (one query per id)
for uid in user_ids:
    user = await session.get(User, uid)

# CORRECT — one query for all
users = (await session.scalars(
    select(User).where(User.id.in_(user_ids))
)).all()
```
*Why: N round-trips to the DB dominate latency; one `IN` query is a single round-trip.*

**For relationship N+1 → `selectinload`** (Section 6). **For repeated single-PK access of already-loaded objects → `session.get()`** uses the identity map (no SQL).

**Bulk writes — never `add()` in a loop:**
```python
# WRONG
for row in rows:
    session.add(User(**row))   # unit-of-work overhead per object

# CORRECT — ORM, one flush
session.add_all([User(**row) for row in rows])
await session.commit()

# FASTEST — Core bulk insert (list of dicts as 2nd arg, not .values())
from sqlalchemy import insert
await session.execute(insert(User), [{"email": e} for e in emails])
await session.commit()
```

**Bulk UPDATE / DELETE — one statement, not a loop:**
```python
from sqlalchemy import update, delete
await session.execute(update(User).where(User.id.in_(ids)).values(is_active=False))
await session.execute(delete(User).where(User.id.in_(ids)))
```
*Note: ORM-enabled bulk UPDATE/DELETE use `synchronize_session` (default `"auto"`) to keep in-session objects consistent — leave it at `"auto"` unless profiling says otherwise.*

---

## Section 9 — Counting & Aggregation

**Rule: count in the database. Never fetch rows to count them.**

```python
from sqlalchemy import func

# WRONG — loads every row into memory just to count
n = len((await session.scalars(select(User).where(User.is_active.is_(True)))).all())

# CORRECT
n = await session.scalar(
    select(func.count()).select_from(User).where(User.is_active.is_(True))
)
```
*Why: `len(.all())` transfers the whole result set; `COUNT(*)` returns a single integer.*

**Other aggregates — same pattern:** `func.sum(col)`, `func.avg(col)`, `func.max(col)`, `func.min(col)`.

**Group / having / conditional count (PostgreSQL `FILTER`):**
```python
stmt = (
    select(User.team_id,
           func.count().label("total"),
           func.count().filter(User.is_active.is_(True)).label("active"))
    .group_by(User.team_id)
    .having(func.count() > 5)
)
rows = (await session.execute(stmt)).all()
```

---

## Section 10 — Subqueries, EXISTS, CTEs

```python
from sqlalchemy import exists, select, func, union_all

# WRONG — IN (subquery) materializes the entire id set just to test membership
select(User).where(User.id.in_(select(Order.user_id).where(Order.total > 100)))  # for "has any", prefer EXISTS

# CORRECT — EXISTS short-circuits on the first matching row
select(User).where(select(1).where(Order.user_id == User.id, Order.total > 100).exists())

# Scalar subquery as a value
order_count = (
    select(func.count(Order.id)).where(Order.user_id == User.id).scalar_subquery()
)

# EXISTS — prefer over IN for "has any" checks
has_admin = await session.scalar(select(exists().where(Role.name == "admin")))

# Relationship EXISTS helpers
select(User).where(User.roles.any(Role.name == "admin"))   # collection: any()
select(Order).where(Order.customer.has(User.is_active.is_(True)))  # scalar: has()
```
*Why `exists()` over `IN (subquery)`: the planner short-circuits on the first match instead of materializing the full set.*

**Recursive CTE (tree expansion) — always include a depth guard / `UNION ALL`:**
```python
# Base term: roots
base = select(Node.id, Node.parent_id, literal(0).label("depth")).where(Node.parent_id.is_(None))
cte = base.cte("tree", recursive=True)
parent = cte.alias()
# Recursive term: children of already-collected nodes, with a depth cap
recursive = (
    select(Node.id, Node.parent_id, (parent.c.depth + 1).label("depth"))
    .join(parent, Node.parent_id == parent.c.id)
    .where(parent.c.depth < 10)   # guard against cycles / runaway recursion
)
cte = cte.union_all(recursive)
rows = (await session.execute(select(cte.c.id, cte.c.depth))).all()
```
*Why the depth guard: a cycle in self-referential data makes a recursive CTE loop forever.*

---

## Section 11 — Transactions

**Rule: the unit of work owns the transaction. Use `session.begin()` in the service layer; repository helpers stage work and never commit.**

```python
# WRONG — repository helper commits; caller can no longer roll back the whole unit of work
async def create_user(session, data):
    user = User(**data)
    session.add(user)
    await session.commit()              # 💥 partial commit — if assign_role later fails, user persists

# CORRECT — service layer owns the transaction boundary; repos only stage work
async with async_session() as session:
    async with session.begin():         # commit on success, rollback on exception
        await create_user(session, data)
        await assign_role(session, user_id, role_id)
# both succeed or both roll back
```
*Why: if a repository commits, a later step's failure can't roll back the earlier write — you get partial, inconsistent state.*

- **`await session.flush()`** — push pending changes to the DB (assigns PKs, runs constraints) without committing. Use when you need a generated PK mid-transaction.
- **`await session.commit()`** — flush + COMMIT. **`await session.rollback()`** — discard everything since the last commit.
- **`await session.refresh(obj)`** — reload from DB (needed only when `expire_on_commit=True`).
- **Savepoints — `async with session.begin_nested():`** — partial rollback inside a larger transaction (e.g. retrying one row in a batch without aborting the rest).

---

## Section 12 — PostgreSQL-Specific Patterns

**Types** (import from `sqlalchemy.dialects.postgresql as pg`):
```python
from sqlalchemy import JSON, Uuid
from sqlalchemy.dialects import postgresql as pg

# WRONG — plain JSON (text storage, not indexable, no containment operators)
data: Mapped[dict] = mapped_column(JSON, default=dict)

# CORRECT
id:    Mapped[uuid.UUID] = mapped_column(Uuid, default=uuid4)        # portable, native UUID on PG
data:  Mapped[dict]      = mapped_column(pg.JSONB, default=dict)     # ALWAYS JSONB, never JSON
tags:  Mapped[list[str]] = mapped_column(pg.ARRAY(String))
ip:    Mapped[str]       = mapped_column(pg.INET)
status: Mapped[str]      = mapped_column(pg.ENUM("a", "b", name="my_enum", create_type=False))
```
*Why JSONB over JSON: JSONB is binary, indexable (GIN), and supports containment operators. Plain JSON is text — no indexing. Why `create_type=False`: lets Alembic manage the `CREATE TYPE` so the migration doesn't try to recreate it.*
*`pg.UUID(as_uuid=True)` is the PG-specific equivalent of `Uuid` — use core `Uuid` unless you need PG-only behavior.*

**JSONB operations** (operators verified against the PG dialect):
```python
Model.data.op("->>")("key")        # -> 'key'::text   (text value)
Model.data.op("->")("key")         # -> 'key'         (json value)
Model.data.contains({"k": "v"})    # @>  containment
Model.data.has_key("k")            # ?   key exists
Model.data.has_any(["a", "b"])     # ?|  any key exists
func.jsonb_set(Model.data, "{k}", '"v"')   # update nested key
```

**Upsert — `INSERT ... ON CONFLICT`** (must import `insert` from the PG dialect):
```python
from sqlalchemy.dialects.postgresql import insert as pg_insert

stmt = pg_insert(User).values([{"email": e, "name": n} for e, n in rows])
stmt = stmt.on_conflict_do_update(
    index_elements=[User.email],                       # the unique key
    set_={"name": stmt.excluded.name, "updated": func.now()},  # excluded = the row that failed to insert
)
await session.execute(stmt)
# Ignore-on-conflict variant:
await session.execute(pg_insert(User).values(...).on_conflict_do_nothing(index_elements=[User.email]))
```

**RETURNING:**
```python
stmt = pg_insert(User).values(email="a@b.c").returning(User.id, User.created)
row = (await session.execute(stmt)).one()
```

**Window functions:**
```python
func.row_number().over(partition_by=Order.user_id, order_by=Order.created.desc())
func.rank().over(order_by=Order.total.desc())
func.lag(Order.total).over(order_by=Order.created)
```

**Full-text search:**
```python
# Query
stmt = select(Doc).where(
    func.to_tsvector("english", Doc.body).op("@@")(func.plainto_tsquery("english", q))
)
# Index (GIN on the tsvector expression)
Index("ix_doc_fts", func.to_tsvector("english", Doc.body), postgresql_using="gin")
```

**Common `func.*`:** `func.now()`, `func.gen_random_uuid()`, `func.coalesce(col, default)`, `func.nullif(col, "")`, `func.array_agg(col)`, `func.string_agg(col, ", ")`.

---

## Section 13 — Indexes & Constraints

All in `__table_args__`:
```python
from sqlalchemy import Index, UniqueConstraint, CheckConstraint, ForeignKeyConstraint, func

# WRONG — plain index on email, but queries filter func.lower(email): the index is never used
#   Index("ix_user_email", "email")  + WHERE func.lower(email) == x   → sequential scan
#   Index("ix_user_meta_btree", "meta")  → B-tree can't serve JSONB containment (@>)

# CORRECT
__table_args__ = (
    Index("ix_user_email_lower", func.lower(User.email)),                  # functional
    Index("ix_user_meta", "meta", postgresql_using="gin"),                 # GIN for JSONB/ARRAY/FTS
    Index("ix_user_active", "team_id",
          postgresql_where=text("is_active")),                            # partial index
    Index("ix_order_cover", "user_id", postgresql_include=["status"]),     # covering index
    UniqueConstraint("email", name="uq_user_email"),
    CheckConstraint("age >= 0", name="ck_user_age_nonneg"),
)
```
*Why functional index `lower(email)`: a query filtering `func.lower(email) == x` can only use an index built on `lower(email)`. Why GIN: B-tree can't index JSONB/array containment. Why partial: a `WHERE is_active` index is smaller and faster when you only ever query active rows.*

For multi-column FKs use `ForeignKeyConstraint([...], [...], ondelete="CASCADE", name="fk_...")`.

---

## Section 14 — Hybrid & Column Properties

**`@hybrid_property`** — one definition that works as a Python attribute AND in SQL `WHERE`. **Use the `.inplace.expression` form (2.0.4+)** so type checkers stay happy:
```python
from sqlalchemy.ext.hybrid import hybrid_property
from sqlalchemy import ColumnElement, func, type_coerce, Float

class Interval(Base):
    start: Mapped[int]
    end: Mapped[int]

    @hybrid_property
    def length(self) -> int:               # Python side
        return self.end - self.start

    # WRONG — redefining `length` as the expression trips PEP 484 type checkers
    # @length.expression
    # def length(cls):
    #     return cls.end - cls.start

    # CORRECT — .inplace lets the SQL method keep a private name (2.0.4+)
    @length.inplace.expression
    @classmethod
    def _length_expr(cls) -> ColumnElement[int]:   # SQL side
        return cls.end - cls.start
```
*Why `.inplace`: the old `@length.expression` redefines the same name and trips PEP 484 checkers. `.inplace` mutates the hybrid in place so the SQL method can have a private name.*

**`column_property()`** — a read-only column computed from a subquery, loaded with the entity:
```python
from sqlalchemy.orm import column_property
order_count: Mapped[int] = column_property(
    select(func.count(Order.id)).where(Order.user_id == id).correlate_except(Order).scalar_subquery()
)
```

**`association_proxy`** — expose a nested attribute directly (e.g. `user.role_names` from `user.roles[].name`).

---

## Section 15 — Events

**Events are synchronous.** Inside a handler: no `await`, no lazy loads, no ORM queries needing the greenlet. Emit SQL only through the passed `connection`.

```python
from sqlalchemy import event
from sqlalchemy.orm import Session

# WRONG — events are synchronous; awaiting or lazy-loading inside one fails
@event.listens_for(Model, "before_insert")
async def bad(mapper, connection, target):     # handler can't be a coroutine
    target.owner = await fetch_owner(target.owner_id)   # 💥 no greenlet here

# CORRECT — set local attributes only; emit SQL via the passed connection
@event.listens_for(Model, "before_insert")
def set_defaults(mapper, connection, target):
    target.slug = slugify(target.name)

@event.listens_for(Session, "before_flush")
def audit(session, flush_context, instances):
    for obj in session.new:
        ...   # inspect pending objects
```

**In async, attach session events to the sync session class:**
```python
@event.listens_for(AsyncSession.sync_session_class, "before_flush")
def _before_flush(session, ctx, instances):
    ...
```

**`@event.listens_for(Engine, "connect")`** — set per-connection options (e.g. statement timeout, timezone) at connect time.

---

## Section 16 — Testing with Async SQLAlchemy

**Rule: never mock the session. Use a real database (test PostgreSQL, or SQLite for pure-ORM unit tests).** Wrap each test in a transaction and roll back — no real commits, full isolation.

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

# WRONG — mocking the session tests your mocks, not your SQL
def test_create_user():
    session = MagicMock()
    session.scalar.return_value = User(id=1)   # never exercises real query/constraints

# CORRECT — real DB, transaction per test, rolled back for isolation
@pytest.fixture
async def session(engine):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSession(engine, expire_on_commit=False) as s:
        yield s
        await s.rollback()
```
*Why real DB: mocked sessions test your mocks, not your SQL — they miss constraint violations, type coercion, and N+1s. Why rollback per test: deterministic, isolated, no cross-test state.*

**`pyproject.toml`:** `[tool.pytest.ini_options]` → `asyncio_mode = "auto"`. Build test objects with factories (e.g. `factory_boy`), not hand-written dicts repeated across tests.

---

## Section 17 — Connection Pool & Engine Configuration

```python
# WRONG — logs every statement in prod, and stale pooled connections fail requests
engine = create_async_engine(DATABASE_URL, echo=True)   # no pre_ping, no recycle

# CORRECT
engine = create_async_engine(
    DATABASE_URL,
    pool_size=10,         # persistent connections kept open
    max_overflow=20,      # extra connections allowed under burst load
    pool_timeout=30,      # seconds to wait for a free connection before erroring
    pool_recycle=1800,    # recycle connections older than 30 min (avoids server-side timeouts)
    pool_pre_ping=True,   # test a connection's liveness before handing it out
    echo=False,           # True only in local dev
)
```
*Why `pool_pre_ping`: a DB restart or idle timeout leaves dead connections in the pool; pre-ping replaces them transparently instead of failing the request. Why `pool_recycle`: prevents the DB from closing a connection mid-request after its idle timeout.*

**Serverless / Lambda / external pooler (pgbouncer):** use `poolclass=NullPool` — no persistent pool; create and drop per request. *Why: a long-lived pool is useless when the runtime freezes between invocations, and double-pooling behind pgbouncer causes connection storms.*

---

## Section 18 — Alembic Integration

**Rule: never hand-write migration bodies — always autogenerate, then review.**
```bash
# WRONG — empty hand-written revision; drifts from the models, misses constraints/types
alembic revision -m "add is_active"      # then manually typing op.add_column(...)

# CORRECT — autogenerate from model metadata, then read the diff before applying
alembic revision --autogenerate -m "add user.is_active"
```

```python
# WRONG — autogenerate emits drop+add for a rename → silently destroys the column's data
op.drop_column("user", "fullname")
op.add_column("user", sa.Column("full_name", sa.String()))

# CORRECT — rename preserves data
op.alter_column("user", "fullname", new_column_name="full_name")
```

- In `env.py`: `target_metadata = Base.metadata` so autogenerate sees your models.
- **Always read the generated migration** — autogenerate misses column renames (it drops + recreates, losing data), some constraint changes, and server-default changes. Fix renames manually: `op.alter_column("user", "old", new_column_name="new")`.
- **PostgreSQL ENUMs:** declare `pg.ENUM(..., create_type=False)` on the model and let the migration own `CREATE TYPE` / `DROP TYPE` via `op.execute(...)`, so re-running doesn't error on an existing type.
- **Data migrations:** `op.execute("UPDATE ...")` in the migration body.
- `include_schemas=True` in the context config for multi-schema databases.
- Batch mode is for SQLite only — not needed for PostgreSQL.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `MissingGreenlet: greenlet_spawn has not been called` | Lazy load / expired-attribute access in async | Add `selectinload`/`joinedload`; set `expire_on_commit=False` |
| `InvalidRequestError: ... can't be used with ... joined eager load` (collections) | `joinedload` on a collection without dedupe | Add `.unique()` to the result, or use `selectinload` |
| `selectinload(...).where(...)` AttributeError / no-op | Load options have no `.where()` | Use `selectinload(Model.rel.and_(...))` |
| `SAWarning: TypeDecorator ... will not produce a cache key` | `cache_ok` unset on a custom type | Set `cache_ok = True` |
| `DetachedInstanceError` | Accessing attributes after the session closed | Load needed data inside the session, or `expire_on_commit=False` |
| Duplicate rows from a query | Cartesian product from `joinedload` collection | `.unique()` or `selectinload` |
| Enum `DuplicateObject` on migration | ENUM type recreated | `create_type=False` + let Alembic manage `CREATE TYPE` |
| Connection errors after idle | Stale pooled connection | `pool_pre_ping=True` + `pool_recycle` |

---

## Keeping This Skill Current

- **Discover a pattern not covered here while working?** Add it to the relevant section of this skill's `SKILL.md` — edit your local copy, and open a PR to the source repo so everyone benefits.
- **User hits a SQLAlchemy error not listed?** Add the symptom + cause + fix to the Troubleshooting table.
- **Upgrading SQLAlchemy?** Check https://docs.sqlalchemy.org/en/20/changelog/ — minor 2.0.x releases add patterns (e.g. `load_only(raiseload=)` in 2.0, `AsyncAttrs` in 2.0.13, hybrid `.inplace` in 2.0.4).
- **When updating: only add; never remove** unless the changelog explicitly deprecates something.
- **After any update**, append the date and what changed below.

### Changelog
- 2026-06-17 — Initial version. Verified against SQLAlchemy 2.0 docs (release line 2.0.51). Covers Sections 1–18, cheatsheet, pre-query checklist, troubleshooting. Key verified corrections vs common mistakes: eager-load filtering uses `relationship.and_()` not `.where()`; `joinedload` collections require `.unique()`; core `Uuid` preferred over `pg.UUID`; `TypeDecorator.cache_ok=True` required; hybrid `.inplace.expression` for type-checker compliance.
- 2026-06-28 — Packaged into the `omar-skills` marketplace: reworded the "Keeping This Skill Current" path to be install-agnostic, tightened the description triggers to stay SQLAlchemy-specific, and removed a contradictory `IN (subquery)` example in §10.
