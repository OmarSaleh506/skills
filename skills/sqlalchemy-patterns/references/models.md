# Models, Relationships, Types, Indexes, Hybrids

Deep reference for declaring mapped classes. SKILL.md has the one-line rules; this file has the full patterns and the reasoning.

## Contents
1. Declarative base and columns
2. Defaults: `default` / `insert_default` / `server_default` / `onupdate`
3. Relationships
4. Large collections: `WriteOnlyMapped` vs `DynamicMapped`
5. Type safety with `Mapped[]`
6. Indexes and constraints
7. Hybrid and column properties

---

## 1. Declarative base and columns

**Subclass `DeclarativeBase`.** `declarative_base()` is the legacy 1.x factory; the class form gives full PEP 484 typing with no plugins.

```python
# WRONG — legacy
from sqlalchemy.orm import declarative_base
Base = declarative_base()
class User(Base):
    id = Column(Integer, primary_key=True)   # untyped, no Mapped[]

# CORRECT — 2.0 / 2.1
import datetime
import uuid
from uuid import uuid4

from sqlalchemy import DateTime, MetaData, func, text
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Constraint naming convention — so Alembic generates stable, predictable names.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

class Base(AsyncAttrs, DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
    type_annotation_map = {
        datetime.datetime: DateTime(timezone=True),   # TIMESTAMP WITH TIME ZONE
    }
```
*Why the naming convention: unnamed constraints get DB-assigned names, and Alembic autogenerate cannot detect anonymously named constraints. Why the `datetime` entry: the default type map turns `Mapped[datetime]` into `DateTime()` — `TIMESTAMP WITHOUT TIME ZONE` on PostgreSQL. Mapping it once on the base makes every timestamp column timezone-aware. Why `AsyncAttrs`: it adds `obj.awaitable_attrs.<name>` for the rare lazy access in async (see `async-sessions.md`).*

**Every column is `mapped_column()` + `Mapped[T]`.** `mapped_column()` reads the annotation for type and nullability. Bare `Column()` carries no ORM typing.

**Nullability is inferred from the annotation — don't also pass `nullable=`:**

```python
class User(Base):
    __tablename__ = "user"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid4)
    email: Mapped[str]              # NOT NULL
    full_name: Mapped[str | None]   # NULL
    is_active: Mapped[bool] = mapped_column(server_default=text("true"))
```
*`Mapped[str]` → NOT NULL, `Mapped[str | None]` → NULL. `Mapped[uuid.UUID]` resolves to the core `Uuid` type via the default type map (native `UUID` on PostgreSQL), so passing `Uuid` explicitly is optional.*

**Integer PK:** `id: Mapped[int] = mapped_column(primary_key=True)` (autoincrement is implicit).

**Mixins for shared columns** — not copy-paste:

```python
class TimestampMixin:
    created: Mapped[datetime.datetime] = mapped_column(server_default=func.now())

class User(TimestampMixin, Base):
    __tablename__ = "user"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid4)
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

## 2. Defaults

| Parameter | Where it runs | Notes |
|---|---|---|
| `default=` | Python, at INSERT (also the dataclass `__init__` default under `MappedAsDataclass`) | Callable → called per row (`default=uuid4`, `default=dict`) |
| `insert_default=` | Python, at INSERT | Supersedes `default` for the column; use it with dataclass mappings when the constructor default and the INSERT default differ |
| `server_default=` | Database (DDL `DEFAULT`) | Fetched back with RETURNING after INSERT on PostgreSQL (`eager_defaults="auto"`) |
| `onupdate=` | SQL rendered into each UPDATE | **Not** fetched back by default — attribute is expired after the flush |
| `server_onupdate=FetchedValue()` | Marker: "the DB/expression sets this on UPDATE" | Combine with `eager_defaults=True` to RETURN it |

```python
# WRONG — created set by the app clock, drifts between app servers, naive datetime
created: Mapped[datetime.datetime] = mapped_column(default=datetime.datetime.utcnow)

# CORRECT — database clock, single source of truth
created: Mapped[datetime.datetime] = mapped_column(server_default=func.now())
```

**`updated` columns in async need one more step.** `onupdate=func.now()` is a client-invoked SQL expression; the ORM does not fetch its value after the UPDATE, so the attribute is expired and the next access needs IO — a `MissingGreenlet` in async even with `expire_on_commit=False`. Mark it fetchable and turn on eager defaults:

```python
from sqlalchemy import FetchedValue

class Article(TimestampMixin, Base):
    __tablename__ = "article"
    id: Mapped[int] = mapped_column(primary_key=True)
    updated: Mapped[datetime.datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        server_onupdate=FetchedValue(),   # tell the ORM the value comes back from SQL
    )
    __mapper_args__ = {"eager_defaults": True}   # RETURNING on UPDATE too
```
*Why: `eager_defaults="auto"` (the default) only applies to INSERT. With `True` + `FetchedValue()` the UPDATE emits `RETURNING article.updated`. Alternative: `await session.refresh(obj, ["updated"])` where you need it.*

**PostgreSQL 18 `uuidv7()` server-side PKs (SQLAlchemy 2.1):** pass `monotonic=True` so batched INSERT..RETURNING can correlate rows:
```python
id: Mapped[uuid.UUID] = mapped_column(
    server_default=func.uuidv7(monotonic=True), primary_key=True
)
```

---

## 3. Relationships

**Type the relationship with `Mapped[...]` and pair both sides with `back_populates`. Never use `backref`** (it hides the reverse side from type checkers and configures it implicitly; the docs call it legacy).

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

**Cascades in async — list them explicitly, don't use `"all"`.** `"all"` is a synonym for `save-update, merge, refresh-expire, expunge, delete`; the `refresh-expire` part expires related objects more aggressively than is appropriate with asyncio. Pair the ORM cascade with a DB-side `ondelete="CASCADE"` + `passive_deletes=True`:
```python
children: Mapped[list["Child"]] = relationship(
    back_populates="parent",
    cascade="save-update, merge, expunge, delete, delete-orphan",
    passive_deletes=True,
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
(`Column` is correct inside a Core `Table`; the "never bare `Column()`" rule is about ORM class attributes.)

**Many-to-many WITH extra columns — association object:**
```python
class UserRole(Base):
    __tablename__ = "user_role"
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), primary_key=True)
    role_id: Mapped[int] = mapped_column(ForeignKey("role.id"), primary_key=True)
    granted_at: Mapped[datetime.datetime] = mapped_column(server_default=func.now())
    user: Mapped["User"] = relationship(back_populates="role_links")
    role: Mapped["Role"] = relationship(back_populates="user_links")
```
*`secondary=` can't store columns on the join. The moment the link needs its own data, use an association object.*

**`viewonly=True`** — read-only relationship (computed join, never flushed). Mutations to it are ignored, so never write through one.

**Self-referential (trees)** — set `remote_side` to the PK:
```python
class Node(Base):
    __tablename__ = "node"
    id: Mapped[int] = mapped_column(primary_key=True)
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("node.id"))
    children: Mapped[list["Node"]] = relationship(back_populates="parent")
    parent: Mapped["Node | None"] = relationship(back_populates="children", remote_side=[id])
```

**Non-FK join — `primaryjoin`** with `foreign()`/`remote()` markers when there is no real ForeignKey. Always `viewonly=True` for these.

**Catch accidental lazy loads at mapping time:** `lazy="raise"` (always raise) or `lazy="raise_on_sql"` (raise only when the load would emit SQL). The asyncio docs recommend `lazy="raise"` when you are not using `AsyncAttrs`, so every access needs an explicit eager loader.

---

## 4. Large collections: `WriteOnlyMapped` vs `DynamicMapped`

For a collection that may hold thousands+ rows (transactions, events, messages), never load it as a `list`:

```python
from sqlalchemy.orm import WriteOnlyMapped

class Account(Base):
    __tablename__ = "account"
    id: Mapped[int] = mapped_column(primary_key=True)
    transactions: WriteOnlyMapped["AccountTransaction"] = relationship(
        cascade="save-update, merge, expunge, delete, delete-orphan",
        passive_deletes=True,
        order_by="AccountTransaction.created",
    )

# usage
account.transactions.add(AccountTransaction(amount=10))          # staged, flushed later
stmt = account.transactions.select().where(AccountTransaction.amount > 100).limit(50)
recent = (await session.scalars(stmt)).all()
```
- **`WriteOnlyMapped`** (`lazy="write_only"`) never loads implicitly; you `.add()` / `.add_all()` / `.remove()` and query via `.select()`. **Fully asyncio-compatible.**
- **`DynamicMapped`** (`lazy="dynamic"`) is the legacy form; it returns a legacy `Query` and is **not compatible with asyncio** (usable only inside `run_sync()`). Don't use it in new async code.
- A write-only collection can't be replaced wholesale on a persistent object (`obj.coll = [...]` raises).

---

## 5. Type safety with `Mapped[]`

```python
# WRONG — untyped column (no Mapped[T]) and a shared mutable default
class Account(Base):
    id = mapped_column(Integer, primary_key=True)          # no Mapped[] → no type checking
    meta: Mapped[dict] = mapped_column(JSONB, default={})  # {} shared across ALL rows

# CORRECT
import enum
from sqlalchemy import Enum, String
from sqlalchemy.dialects.postgresql import ARRAY, JSONB

class Status(enum.Enum):
    ACTIVE = "active"
    BANNED = "banned"

class Account(Base):
    __tablename__ = "account"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    status: Mapped[Status] = mapped_column(Enum(Status, name="account_status"))
    tags: Mapped[list[str]] = mapped_column(ARRAY(String))
    meta: Mapped[dict] = mapped_column(JSONB, default=dict)   # fresh {} per row
```
*`default={}` is one dict shared by every instance — a classic mutable-default bug. `default=dict` calls the factory per row.*

**`type_annotation_map` — map a Python type to a SQL type once, project-wide.** Use `Annotated` to give one Python type several SQL variants:
```python
from typing import Annotated

str_255 = Annotated[str, 255]

class Base(DeclarativeBase):
    type_annotation_map = {
        str_255: String(255),
        dict: JSONB,
        datetime.datetime: DateTime(timezone=True),
    }

class User(Base):
    __tablename__ = "user"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str_255]   # → VARCHAR(255)
    meta: Mapped[dict]      # → JSONB
```
PEP 695 `type` aliases (`TypeAliasType`) are also resolved through the map.

**Custom domain type — `TypeDecorator` (always set `cache_ok`):**
```python
from sqlalchemy import types

class LowerString(types.TypeDecorator):
    impl = types.String
    cache_ok = True   # required — unset disables statement caching and warns
    def process_bind_param(self, value, dialect):
        return value.lower() if value is not None else value
```
*SQLAlchemy caches compiled statements keyed by type. An unset `cache_ok` emits a warning and disables caching for every statement using the type.*

---

## 6. Indexes and constraints

All in `__table_args__`:
```python
from sqlalchemy import CheckConstraint, Index, UniqueConstraint, func, text

# WRONG — plain index on email, but queries filter func.lower(email): the index is never used
#   Index("ix_user_email", "email")  + WHERE func.lower(email) == x   → sequential scan
#   Index("ix_user_meta_btree", "meta")  → B-tree can't serve JSONB containment (@>)

# CORRECT (inside class User)
__table_args__ = (
    Index("ix_user_meta", "meta", postgresql_using="gin"),                 # GIN for JSONB/ARRAY/FTS
    Index("ix_user_active", "team_id", postgresql_where=text("is_active")),  # partial
    Index("ix_order_cover", "user_id", postgresql_include=["status"]),     # covering
    UniqueConstraint("email", name="uq_user_email"),
    CheckConstraint("age >= 0", name="ck_user_age_nonneg"),
)

# Functional index — declare after the class body, where User.email exists
Index("ix_user_email_lower", func.lower(User.email))
```
*A query filtering `func.lower(email) == x` can only use an index built on `lower(email)`. B-tree can't index JSONB/array containment — use GIN. A partial index is smaller and faster when you only ever query the subset.*

Multi-column FKs: `ForeignKeyConstraint([...], [...], ondelete="CASCADE", name="fk_...")`.

**Computed columns on PostgreSQL 18+ with SQLAlchemy 2.1:** `Computed("...")` now renders as VIRTUAL by default; pass `Computed("x * x", persisted=True)` to keep a STORED column.

---

## 7. Hybrid and column properties

**`@hybrid_property`** — one definition that works as a Python attribute AND in SQL. Use the `.inplace` form (2.0.4+) so type checkers stay happy:
```python
from sqlalchemy import ColumnElement
from sqlalchemy.ext.hybrid import hybrid_property

class Interval(Base):
    __tablename__ = "interval"
    id: Mapped[int] = mapped_column(primary_key=True)
    start: Mapped[int]
    end: Mapped[int]

    @hybrid_property
    def length(self) -> int:               # Python side
        return self.end - self.start

    @length.inplace.expression
    @classmethod
    def _length_expr(cls) -> ColumnElement[int]:   # SQL side
        return cls.end - cls.start
```
*The old `@length.expression` redefines the same name and trips PEP 484 checkers. `.inplace` mutates the hybrid so the SQL method can have a private name.*

**`column_property()`** — read-only column computed from a correlated subquery, loaded with the entity:
```python
from sqlalchemy.orm import column_property
order_count: Mapped[int] = column_property(
    select(func.count(Order.id)).where(Order.user_id == id).correlate_except(Order).scalar_subquery()
)
```

**`association_proxy`** — expose a nested attribute directly (e.g. `user.role_names` from `user.roles[].name`).
