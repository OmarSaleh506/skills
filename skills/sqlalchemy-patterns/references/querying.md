# Querying, Bulk Writes, Counting, Subqueries

## Contents
1. SELECT and terminal methods
2. Filtering operators
3. N+1 elimination
4. Bulk INSERT / UPDATE / DELETE (incl. RETURNING)
5. Counting and aggregation
6. Subqueries, EXISTS, CTEs

---

## 1. SELECT and terminal methods

```python
from sqlalchemy import and_, not_, nulls_last, or_, select

# Whole entities → list[Model]
stmt = select(User).where(User.is_active.is_(True)).order_by(User.created.desc())
users = (await session.scalars(stmt)).all()

# Specific columns → list[Row]
stmt = select(User.id, User.email)
rows = (await session.execute(stmt)).all()   # each row: row.id, row.email
```

- **WHERE:** multiple `.where(a, b)` args or `and_(a, b)` = AND; `or_(...)`; `not_(...)` / `~`.
- **Ordering:** `col.desc()`, `col.asc()`, `nulls_last(col)`. **Pagination:** `.limit(n).offset(m)`.
- **Distinct:** `.distinct()`, or PostgreSQL `DISTINCT ON`: `select(User).distinct(User.email)`.

| Call | Returns |
|---|---|
| `(await session.scalars(stmt)).all()` | `list[Model]` (ORM objects) |
| `await session.scalar(stmt)` | first column of first row, or `None` |
| `(await session.execute(stmt)).scalar_one()` | exactly one value; raises if 0 or >1 |
| `(await session.execute(stmt)).scalar_one_or_none()` | one or `None`; raises if >1 |
| `(await session.execute(stmt)).first()` | first `Row` or `None` |
| `(await session.execute(stmt)).all()` | `list[Row]` (tuple-like; typed `Row[int, str]` in 2.1) |
| `await session.get(Model, pk)` | identity-map lookup first, SELECT only on a miss |

*`scalar_one_or_none()` for "fetch by unique key" asserts uniqueness — a duplicate raises instead of silently returning the first.*

---

## 2. Filtering operators

```python
# WRONG
select(User).where(User.deleted_at == None)   # linters flag it; intent unclear
select(User).filter_by(age > 18)              # filter_by takes kwargs only → error

# CORRECT
select(User).where(User.deleted_at.is_(None))  # IS NULL
select(User).where(User.age > 18)              # .where() for anything but simple equality

User.id.in_(ids)                         # IN
User.id.not_in(ids)                      # NOT IN
User.email.ilike("%@example.test")        # case-insensitive LIKE
User.age.between(18, 65)
User.deleted_at.is_not(None)             # IS NOT NULL
func.lower(User.email) == email.lower()  # case-insensitive equality

from sqlalchemy import exists
stmt = select(exists().where(User.email == email))   # await session.scalar(stmt) → bool
```

*2.1: `filter_by()` searches every entity in the FROM clause and raises `AmbiguousColumnError` when the name exists in more than one — use `.where(Entity.col == v)` with joins.*

---

## 3. N+1 elimination

N+1 = one query for N rows, then one query per row inside a loop.

```python
# WRONG — one query per id
for uid in user_ids:
    user = await session.get(User, uid)

# CORRECT — one round-trip
users = (await session.scalars(select(User).where(User.id.in_(user_ids)))).all()
by_id = {u.id: u for u in users}   # dict for keyed lookups
```
- Relationship N+1 → `selectinload` / `joinedload` (see `loading.md`).
- Repeated single-PK access of objects already in the session → `session.get()` hits the identity map (no SQL).

---

## 4. Bulk INSERT / UPDATE / DELETE

**Never `add()` in a loop.**
```python
from sqlalchemy import delete, insert, update

# ORM unit of work, one flush — use when you need the objects (events, relationships, defaults)
session.add_all([User(**row) for row in rows])

# ORM bulk INSERT — list of dicts as the 2nd argument (not .values()); keys are attribute names
await session.execute(insert(User), [{"email": e} for e in emails])

# Bulk INSERT ... RETURNING — get ORM objects back in one batched statement
users = (await session.scalars(insert(User).returning(User), [{"email": e} for e in emails])).all()

# Need rows to line up with the input order? Ask for it explicitly
ids = (await session.scalars(
    insert(User).returning(User.id, sort_by_parameter_order=True), data
)).all()
```
*Most backends don't guarantee RETURNING order; `sort_by_parameter_order=True` (2.0.10+) makes SQLAlchemy guarantee it.*

**Bulk UPDATE by primary key** — list of dicts, each including the full PK; no `.values()`, no WHERE:
```python
await session.execute(update(User), [{"id": 1, "name": "a"}, {"id": 3, "name": "b"}])
```
(RETURNING isn't available in this mode — it uses executemany.)

**UPDATE / DELETE with WHERE criteria — one statement, not a loop:**
```python
await session.execute(update(User).where(User.id.in_(ids)).values(is_active=False))
await session.execute(delete(User).where(User.id.in_(ids)))
```
ORM-enabled UPDATE/DELETE use `synchronize_session` (default `"auto"`) to keep in-session objects consistent — leave it unless profiling says otherwise.

Upserts (`ON CONFLICT`) live in `postgresql.md`.

---

## 5. Counting and aggregation

**Count in the database. Never fetch rows to count them.**
```python
from sqlalchemy import func

# WRONG — loads every row into memory just to count
n = len((await session.scalars(select(User).where(User.is_active.is_(True)))).all())

# CORRECT
n = await session.scalar(
    select(func.count()).select_from(User).where(User.is_active.is_(True))
)
```

Other aggregates: `func.sum(col)`, `func.avg(col)`, `func.max(col)`, `func.min(col)`.

**Group / having / conditional count (PostgreSQL `FILTER`):**
```python
stmt = (
    select(
        User.team_id,
        func.count().label("total"),
        func.count().filter(User.is_active.is_(True)).label("active"),
    )
    .group_by(User.team_id)
    .having(func.count() > 5)
)
rows = (await session.execute(stmt)).all()
```

---

## 6. Subqueries, EXISTS, CTEs

```python
from sqlalchemy import exists, func, literal, select

# "Has any" → EXISTS (short-circuits on first match)
select(User).where(select(1).where(Order.user_id == User.id, Order.total > 100).exists())

# Scalar subquery as a value
order_count = select(func.count(Order.id)).where(Order.user_id == User.id).scalar_subquery()

# Relationship EXISTS helpers
select(User).where(User.roles.any(Role.name == "admin"))            # collection: any()
select(Order).where(Order.customer.has(User.is_active.is_(True)))   # scalar: has()
```

**Recursive CTE (tree expansion) — always include a depth guard:**
```python
base = select(Node.id, Node.parent_id, literal(0).label("depth")).where(Node.parent_id.is_(None))
cte = base.cte("tree", recursive=True)
parent = cte.alias()
recursive = (
    select(Node.id, Node.parent_id, (parent.c.depth + 1).label("depth"))
    .join(parent, Node.parent_id == parent.c.id)
    .where(parent.c.depth < 10)   # guard against cycles / runaway recursion
)
cte = cte.union_all(recursive)
rows = (await session.execute(select(cte.c.id, cte.c.depth))).all()
```
*A cycle in self-referential data makes an unguarded recursive CTE loop forever.*

For self-referential ORM loading, `selectinload(Node.children, recursion_depth=N)` is an alternative (marked experimental).
