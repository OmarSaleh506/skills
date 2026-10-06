# Async Engine, Sessions, Transactions, Events

## Contents
1. Install and engine
2. `async_sessionmaker` and `expire_on_commit`
3. Session scope and transactions
4. Explicit IO: `AsyncAttrs`, `refresh`, `run_sync`
5. Concurrency
6. Events in async
7. Connection pool configuration

---

## 1. Install and engine

```bash
pip install "sqlalchemy[asyncio]" asyncpg        # or: "sqlalchemy[asyncio]" "psycopg[binary]"
```
*SQLAlchemy 2.1 no longer installs `greenlet` by default — it lives only in the `[asyncio]` extra. Without it, the async extension fails at import/first use.*

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine(
    "postgresql+asyncpg://user:pw@host/db",   # or postgresql+psycopg://... (async psycopg 3)
    pool_pre_ping=True,
    echo=False,          # never True in production — logs every statement
)
```
Always spell the driver in the URL. With `create_async_engine`, `postgresql+psycopg://` automatically selects the async psycopg dialect; in 2.1 a bare `postgresql://` means psycopg 3 (it meant psycopg2 in 2.0).

---

## 2. `async_sessionmaker` and `expire_on_commit`

```python
# WRONG — default expire_on_commit=True
async_session = async_sessionmaker(engine)
async with async_session() as s:
    user = await s.get(User, uid)
    await s.commit()
    return user.email   # MissingGreenlet — attribute expired, reload needs IO

# CORRECT
async_session = async_sessionmaker(engine, expire_on_commit=False)
```
*After commit, the default expires every attribute; the next access triggers a reload, which is implicit IO → `MissingGreenlet`. The SQLAlchemy asyncio docs: `expire_on_commit` "should normally be set to False when using asyncio". (`class_=AsyncSession` is the default and can be omitted.)*

Session-wide execution options (2.1): `async_sessionmaker(engine, expire_on_commit=False, execution_options={"schema_translate_map": {None: "tenant_a"}})` applies to queries **and** flushes.

**Read replica:** two engines, two sessionmakers; route read-only handlers to the replica sessionmaker. Names are project-specific.

---

## 3. Session scope and transactions

**Always a context manager** — it returns the connection to the pool even on exceptions.

```python
# Auto-commit on success, auto-rollback on exception
async with async_session() as session:
    async with session.begin():
        session.add(obj)

# Shorthand for the same thing
async with async_session.begin() as session:
    session.add(obj)

# Manual control
async with async_session() as session:
    session.add(obj)
    await session.commit()
```

**The unit of work owns the transaction.** Use `session.begin()` in the service layer; repository helpers stage work and never commit.

```python
# WRONG — repository helper commits; a later failure can't roll back the earlier write
async def create_user(session, data):
    user = User(**data)
    session.add(user)
    await session.commit()

# CORRECT — service layer owns the boundary
async with async_session.begin() as session:
    user = await create_user(session, data)    # add + flush only
    await assign_role(session, user.id, role_id)
# both succeed or both roll back
```

- `await session.flush()` — push pending changes (assigns PKs, runs constraints) without committing.
- `await session.commit()` / `await session.rollback()`.
- `await session.refresh(obj)` — reload from DB. Prefer `refresh()` over `expire()` in async.
- **Savepoints:** `async with session.begin_nested():` — partial rollback inside a larger transaction.
- **Server defaults:** on PostgreSQL, `server_default` values are fetched with RETURNING at INSERT (`eager_defaults="auto"`), so `obj.created` is readable after `flush()` without a refresh. `onupdate` values are **not** — see `models.md` § Defaults.
- **2.1:** autoflush now runs before every execution, including Core and `text()` statements.

---

## 4. Explicit IO: `AsyncAttrs`, `refresh`, `run_sync`

Prefer eager loaders (`loading.md`). For the occasional one-off:

```python
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase

class Base(AsyncAttrs, DeclarativeBase):
    pass

user = await session.get(User, uid)
roles = await user.awaitable_attrs.roles           # 2.0.13+: lazy load as an awaitable
await session.refresh(user, ["roles"])            # 2.0.4+: load a named relationship explicitly
```

- **`session.query()` is the legacy API** — use `select()` + `await session.execute/scalars/scalar/get`.
- **`run_sync()`** runs a sync function with a sync `Connection`/`Session` — for DDL or sync-only APIs:
  ```python
  async with engine.begin() as conn:
      await conn.run_sync(Base.metadata.create_all)
  ```
- When creating new objects, assign empty collections (`User(roles=[])`) so the collection is readable after flush.

---

## 5. Concurrency

**One `AsyncSession` per task.** It's a stateful object representing one transaction; never share it across `asyncio.gather()` tasks.

```python
async def load_one(uid):
    async with async_session() as session:
        return await session.get(User, uid)

users = await asyncio.gather(*(load_one(u) for u in uids))   # each task has its own session
```
(For many ids, one `WHERE id IN (...)` query beats N concurrent sessions.)

---

## 6. Events in async

**Event handlers are synchronous.** No `await`, no lazy loads. Emit SQL only through the passed connection/session.

```python
from sqlalchemy import event
from sqlalchemy.orm import Session, sessionmaker

# WRONG — handlers can't be coroutines
@event.listens_for(Model, "before_insert")
async def bad(mapper, connection, target):
    target.owner = await fetch_owner(target.owner_id)

# CORRECT — set local attributes only
@event.listens_for(Model, "before_insert")
def set_defaults(mapper, connection, target):
    target.slug = slugify(target.name)
```

**Where to attach session/engine events in async** (the documented targets):
```python
# All Session instances (sync and async — AsyncSession proxies a sync Session)
@event.listens_for(Session, "before_flush")
def audit(session, flush_context, instances):
    for obj in session.new:
        ...

# Only sessions from one factory: hand async_sessionmaker a sync sessionmaker as the event target
sync_maker = sessionmaker()
async_session = async_sessionmaker(engine, expire_on_commit=False, sync_session_class=sync_maker)

@event.listens_for(sync_maker, "before_commit")
def before_commit(session):
    ...

# Engine / pool events: target the AsyncEngine's sync_engine
@event.listens_for(engine.sync_engine, "connect")
def on_connect(dbapi_connection, connection_record):
    ...   # e.g. per-connection settings
```
A single `AsyncSession` instance: `event.listens_for(async_session_obj.sync_session, "before_commit")`.

---

## 7. Connection pool configuration

```python
# WRONG — logs every statement in prod; stale pooled connections fail requests
engine = create_async_engine(DATABASE_URL, echo=True)

# CORRECT
engine = create_async_engine(
    DATABASE_URL,
    pool_size=10,         # persistent connections kept open
    max_overflow=20,      # extra connections allowed under burst
    pool_timeout=30,      # seconds to wait for a free connection
    pool_recycle=1800,    # recycle connections older than 30 min
    pool_pre_ping=True,   # liveness check before handing a connection out
)
```
*`pool_pre_ping` replaces dead connections (DB restart, idle timeout) transparently. `pool_recycle` prevents server-side idle timeouts from killing a connection mid-request. Numbers are examples — size from your DB's connection limit.*

**Serverless or behind PgBouncer:** `poolclass=NullPool`. With asyncpg behind PgBouncer also see `postgresql.md` (prepared-statement names).
