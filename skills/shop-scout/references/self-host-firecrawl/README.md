# Self-hosted Firecrawl (recommended backend for shop-scout)

Run your own Firecrawl in Docker so shop-scout gets reliable price extraction on
JS-heavy stores — **no account, no API key, no quota**. This is the setup
shop-scout prefers.

> **⚠️ Security — localhost only.** This stack ships local-dev defaults (no API
> auth, default Postgres password, `BULL_AUTH_KEY=CHANGEME`). Run it on your own
> machine only — do **not** bind port 3002 (or any service) to a public network
> or `0.0.0.0` on an internet-facing host.

## What you get

A standalone stack (all **prebuilt images**, nothing to build from source):

- **api** — Firecrawl API on `http://localhost:3002`, with an internal worker pool.
- **worker ×2** — extra horizontal scrape workers (so `SHOP_PARALLEL` has real
  concurrency to use).
- **redis**, **rabbitmq**, **nuq-postgres** — the queue/state backends Firecrawl needs.
- **playwright-service** — headless browser that renders JS pages.

## Requirements

- Docker + Docker Compose v2 (`docker compose version`).
- Roughly **6–8 GB RAM** free for the stack (Playwright + browsers are the heavy
  part). It runs comfortably on a typical dev laptop.

## Start it

```bash
cd references/self-host-firecrawl     # the folder this README is in
docker compose up -d                  # first run pulls images (a few minutes)
docker compose ps                     # api, 2 workers, redis, rabbitmq, postgres, playwright
```

Wait until the API answers (the harness starts its workers a few seconds after
the container is "Up"):

```bash
curl -s -X POST http://localhost:3002/v2/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com","formats":["markdown"]}' | head -c 200
```

A JSON body with `"success": true` means you're ready.

## Point shop-scout at it

```bash
export FIRECRAWL_API_URL=http://localhost:3002
# leave FIRECRAWL_API_KEY unset — self-host needs no key
```

With `FIRECRAWL_API_URL` set, shop-scout auto-selects the self-host backend
(highest priority). That's it.

## Scaling the workers

The shipped file already runs **2 worker replicas** (`deploy.replicas: 2`). To
push concurrency further, either:

```bash
docker compose up -d --scale worker=3        # more worker containers
```

or raise per-container concurrency in the compose env:

```yaml
NUM_WORKERS_PER_QUEUE: ${NUM_WORKERS_PER_QUEUE:-8}
```

Match this loosely to your `SHOP_PARALLEL` × `SHOP_MAX_LISTINGS` so scrapes don't
queue up. More workers = more RAM/CPU.

## Optional: enable server-side `json` extraction

The no-account self-host has **no LLM**, so Firecrawl's `json` (structured)
extraction format returns HTTP 500. shop-scout handles this by scraping markdown
and extracting fields itself — no action needed. If you'd rather have Firecrawl
return structured fields, set an LLM key in the compose `x-common-env`:

```yaml
OPENAI_API_KEY: sk-...        # your own key
MODEL_NAME: gpt-4o-mini       # or any supported model
```

…then `docker compose up -d` again. (This is the *only* place a key would live,
and it's your choice — the default path needs none.)

## Stop / clean up

```bash
docker compose down        # stop containers, keep nothing persistent of value
docker compose down -v     # also remove volumes (queue state) — use for a clean slate
```

## Troubleshooting

- **`rabbitmq` exits with `.erlang.cookie: eacces`** — a stale volume from a
  previous run. Fix with a clean slate:
  ```bash
  docker compose down -v && docker compose up -d
  ```
- **API never answers on :3002** — check `docker compose logs api`; ensure
  rabbitmq became *healthy* first (`docker compose ps`). The api waits on it.
- **Port 3002 already in use** — set a different host port:
  `PORT=3010 docker compose up -d` and use `http://localhost:3010`.
- **Scrapes are slow / time out** — the first scrape after boot warms the
  browser; give it a moment. Increase `waitFor` per request for slow stores.

> The Firecrawl images are **pinned to digests** (verified 2026-06-29) for
> reproducibility. To move to a newer Firecrawl, follow the "How to bump the
> pin" steps in the header of `docker-compose.yml`. If a newer image changes the
> startup command, check Firecrawl's own `docker-compose.yaml` upstream and
> mirror the `command:`/services here.
