# Relationship and Column Loading

In async, touching an unloaded relationship (or an expired/deferred column) needs implicit IO, which raises `MissingGreenlet` and kills the request. Every relationship you touch needs an explicit loader on the outer query.

## Contents
1. Strategy choice
2. `joinedload` on collections needs `.unique()`
3. Nesting, filtering, global criteria
4. `contains_eager`
5. `raiseload` — turn lazy loads into errors
6. Column loading: `load_only`, `defer`, `undefer`
7. 2.1 behavior notes

---

## 1. Strategy choice

```python
from sqlalchemy.orm import selectinload, joinedload

# WRONG — lazy load in async
users = (await session.scalars(select(User))).all()
for u in users:
    print(u.roles)   # MissingGreenlet

# CORRECT — collection → selectinload (second SELECT ... WHERE id IN (...))
stmt = select(User).options(selectinload(User.roles))
users = (await session.scalars(stmt)).all()

# CORRECT — scalar (many-to-one) → joinedload (LEFT OUTER JOIN, same query)
stmt = select(Order).options(joinedload(Order.customer))
orders = (await session.scalars(stmt)).all()
```

| Relationship | Use | Why |
|---|---|---|
| One-to-many / many-to-many collection | `selectinload` | The docs call it "generally the best loading strategy" for collections: one extra SELECT, original statement untouched, no row multiplication |
| Many-to-one / one-to-one | `joinedload` | Most general-purpose for scalars; `innerjoin=True` when the FK is NOT NULL |
| Huge collection | `WriteOnlyMapped` + explicit `.select()` | Never loaded implicitly (see `models.md`) |
| One-off attribute, no loader planned | `await obj.awaitable_attrs.rel` or `await session.refresh(obj, ["rel"])` | Explicit await instead of implicit IO |
| `subqueryload` | Don't — legacy, superseded by `selectinload` | |
| `lazyload` / `lazy="select"` access | Never in async | Implicit IO |

`selectinload(..., chunksize=N)` (2.1) chunks the IN list for very large parent sets.

---

## 2. `joinedload` on a collection requires `.unique()`

```python
stmt = select(User).options(joinedload(User.roles))   # collection via JOIN
users = (await session.scalars(stmt)).unique().all()  # .unique() mandatory — ORM raises without it
```
The JOIN multiplies parent rows; SQLAlchemy keeps uniquing explicit so it's clear fewer objects than rows come back. Prefer `selectinload` for collections — no `.unique()` needed.

---

## 3. Nesting, filtering, global criteria

**Nesting:**
```python
select(User).options(selectinload(User.roles).selectinload(Role.permissions))
```

**Eager load WITH a filter — `relationship.and_()`, not `.where()`:**
```python
# WRONG — loader options have no .where()
select(User).options(selectinload(User.roles).where(Role.is_active == True))

# CORRECT — criteria attached to the relationship's join condition
select(User).options(selectinload(User.roles.and_(Role.is_active.is_(True))))
```
`.and_()` works identically across `selectinload` / `joinedload` / `lazyload`.

**Global per-entity criteria — `with_loader_criteria()`** (applies everywhere that entity loads, including nested loads — ideal for soft-delete):
```python
from sqlalchemy.orm import with_loader_criteria
select(User).options(
    selectinload(User.roles),
    with_loader_criteria(Role, lambda cls: cls.deleted_at.is_(None)),
)
```

---

## 4. `contains_eager`

When you've already written an explicit `.join()` (e.g. to filter on the joined table) and want it to populate the relationship:
```python
from sqlalchemy.orm import contains_eager
stmt = (
    select(User)
    .join(User.roles)
    .where(Role.name == "admin")
    .options(contains_eager(User.roles))
)
```
Note the collection then only contains the rows that matched the filter.

---

## 5. `raiseload` — turn lazy loads into errors

```python
from sqlalchemy.orm import Load, raiseload

stmt = select(Order).options(joinedload(Order.items), raiseload("*"))           # everything else raises
stmt = select(Order).options(joinedload(Order.items), Load(Order).raiseload("*"))  # only Order's other rels
stmt = select(Order).options(joinedload(Order.items).raiseload("*"))             # only Item's rels
```
- `raiseload("*")` in tests/dev surfaces a missing loader as an immediate, readable error instead of a `MissingGreenlet` deep in a handler.
- `raiseload(..., sql_only=True)` raises only when the load would emit SQL (identity-map hits still work).
- Mapping-level equivalents: `relationship(lazy="raise")` / `lazy="raise_on_sql"`.
- Raiseload does not apply inside the flush process.

---

## 6. Column loading: `load_only`, `defer`, `undefer`

**Every list endpoint uses `load_only()` with only the columns the response returns.** Wide tables carry heavy text/JSONB/blob columns a list view discards.

```python
from sqlalchemy.orm import defer, load_only, undefer

# WRONG — pulls every column
stmt = select(User)

# CORRECT
stmt = select(User).options(load_only(User.id, User.email, User.is_active, User.created))
```

- `defer(col)` — exclude one heavy column. `undefer(col)` — force-load a column deferred at mapping level (`mapped_column(..., deferred=True)`).
- **In async, a deferred column accessed later is implicit IO.** Use `load_only(..., raiseload=True)` (added 2.0) or `defer(col, raiseload=True)` so the mistake raises clearly; `mapped_column(..., deferred=True, deferred_raiseload=True)` does it at mapping level.

**Combine column + relationship loaders in one `.options()`:**
```python
stmt = select(User).options(
    load_only(User.id, User.email),
    selectinload(User.roles).load_only(Role.id, Role.name),
)
```

---

## 7. 2.1 behavior notes

- **Loader options from a deeper path no longer apply to an object loaded at the top.** If the same object is reached through two paths in one query, 2.1 deterministically uses the *shallowest* path's options for later loads (2.0 picked one unpredictably). Code relying on overlapping paths (e.g. a nested `raiseload("*")` leaking onto the top entity) may behave differently.
- `selectinload(chunksize=...)` is new in 2.1. Other 2.1 changes: `migration-2.1.md`.
