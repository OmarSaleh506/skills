# Testing with Async SQLAlchemy

**Never mock the session.** A mocked session tests your mocks, not your SQL — it misses constraint violations, type coercion, cascade behavior, and N+1s. Use a real PostgreSQL test database and roll everything back after each test.

## The pattern: join the session into an outer transaction

SQLAlchemy's documented test-suite recipe ("Joining a Session into an External Transaction"): open a connection, begin a transaction, bind the session to that connection with `join_transaction_mode="create_savepoint"`. Code under test may call `commit()` freely — those become SAVEPOINT releases — and the outer transaction is rolled back at teardown, so nothing persists.

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

@pytest.fixture(scope="session")
async def engine():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest.fixture
async def session(engine):
    async with engine.connect() as conn:
        outer = await conn.begin()
        session = AsyncSession(
            bind=conn,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )
        try:
            yield session
        finally:
            await session.close()
            await outer.rollback()   # undo everything, including "committed" work
```

```python
# WRONG — mocking the session
def test_create_user():
    session = MagicMock()
    session.scalar.return_value = User(id=1)   # never exercises real SQL

# CORRECT — behavior through the public API, real DB
async def test_create_user_persists_email(session):
    await create_user(session, {"email": "a@example.test"})
    found = await session.scalar(select(User).where(User.email == "a@example.test"))
    assert found is not None
```

*Why `create_savepoint` instead of "yield then rollback": with a plain session, a `commit()` inside the code under test really commits, and the test leaks data into the next one. The outer-transaction pattern isolates tests even when the code commits.*

> The SQLAlchemy docs show this recipe with a sync `Session`; the async version above relies on `AsyncSession(...)` forwarding its keyword arguments (including `join_transaction_mode`) to the underlying `Session`, which the `AsyncSession.__init__` docs state.

## Other tips

- **Async test runner:** with `pytest-asyncio`, set `asyncio_mode = "auto"` under `[tool.pytest.ini_options]`, and make session-scoped async fixtures share one event loop (check your plugin version's docs for the loop-scope setting).
- **Catch lazy loads in tests:** add `raiseload("*")` to queries under test, or `lazy="raise"` on relationships, so a missing loader fails loudly (`loading.md`).
- **Schema from migrations, not `create_all`, in CI** when you want to test the migrations themselves: run `alembic upgrade head` against the test DB, and `alembic check` to assert models and migrations agree (`alembic.md`).
- **Factories over hand-written dicts** (e.g. `factory_boy`) for test data; keep data deterministic — no live timestamps or random values in assertions.
- Avoid SQLite as a stand-in for PostgreSQL-specific behavior (JSONB, ARRAY, ON CONFLICT semantics, ENUM types); it's fine only for pure-ORM logic that uses portable types.
