# Firecrawl usage (for shop-scout)

Distilled from Firecrawl's official agent guide
(`https://www.firecrawl.dev/agent-onboarding/SKILL.md`) and verified against the
live v2 API. Firecrawl gives agents reliable web search + clean extraction on
JS-heavy stores where a naive fetch fails.

## The one workflow that matters: search → scrape

**Search first to discover URLs, then scrape only the URLs worth the tokens.**
This maps exactly onto shop-scout's pipeline: Step 1 = `/search`,
Step 2 = `/scrape` the top listings. Don't scrape blind; don't crawl whole sites.

## Which endpoint when

| Need | Endpoint | Notes |
|---|---|---|
| Discover sellers/listings for a product | `POST /search` | Returns ranked web results. Optionally scrape them inline. |
| Read a known listing → clean markdown / fields | `POST /scrape` | The workhorse for price/discount extraction. |
| Page needs clicks / login / "load more" before content appears | `POST /interact` | Browser actions. Rarely needed for shopping; avoid unless a price truly hides behind interaction. |
| Enumerate a site's URLs / bulk pull | `POST /map`, `POST /crawl` | Require an API key (cloud). Overkill — and token-expensive — for shop-scout. Don't use by default. |

Self-hosted instances don't offer the cloud-only `/agent` and `/browser`
endpoints; `/search` and `/scrape` are all shop-scout needs.

## Base URL & auth

- **Self-host:** base = `$FIRECRAWL_API_URL` (e.g. `http://localhost:3002`). **No
  auth header.**
- **Cloud:** base = `https://api.firecrawl.dev/v2`. Header
  `Authorization: Bearer $FIRECRAWL_API_KEY`.

Same request/response shapes either way — only the base URL and auth differ. So
write your calls once and switch on which env var is set (the auto-detect order
in SKILL.md). The bundled `firecrawl.sh` wrapper already does this.

## `POST /search`

Request body:

```json
{
  "query": "logitech mx master 3s buy",
  "limit": 5,
  "sources": ["web"]
}
```

- `query` — the search string. Add `price`, a region word, or `site:` filters to
  sharpen (e.g. `site:noon.com OR site:amazon.sa airpods pro`).
- `limit` — keep small (≈ `SHOP_MAX_LISTINGS`); each result can cost credits on cloud.
- `sources` — `["web"]` for shopping. (`news`, `images` also exist.)
- *(optional)* `scrapeOptions` — if present, Firecrawl scrapes every result inline.
  Powerful but multiplies cost; prefer to search first, then scrape only the
  finalists.

Verified response shape:

```json
{
  "success": true,
  "creditsUsed": 2,
  "data": { "web": [
    { "url": "https://…", "title": "…", "description": "… $99.99 …", "position": 1 }
  ]}
}
```

Read results from `data.web[]`. The `description` snippet sometimes already shows
a price — a free hint before you spend a scrape.

## `POST /scrape`

Request body (the default shop-scout path — markdown, works on self-host *and*
cloud):

```json
{
  "url": "https://www.noon.com/…/p/…",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "location": { "country": "SA" },
  "waitFor": 1500
}
```

- `formats` — `["markdown"]` is the reliable default. Other formats: `html`,
  `rawHtml`, `links`, `screenshot`, and `json` (see below).
- `onlyMainContent: true` — strips nav/footer/ads → fewer tokens, cleaner price area.
- `location.country` — render as if from that region so you get local pricing/currency
  (`SA` for Saudi, `US` for global, etc.).
- `waitFor` — ms to wait for JS to settle on slow stores (use sparingly; it adds latency).

Verified response shape:

```json
{ "success": true,
  "data": { "markdown": "…clean page text incl. price…", "metadata": { … } } }
```

Extract price / list price / discount / stock / shipping / seller from
`data.markdown` yourself.

### Structured extraction with the `json` format (CLOUD, or self-host *with* an LLM key)

On cloud you can have Firecrawl return the fields already structured, saving you
the parse:

```json
{
  "url": "https://…",
  "formats": [
    "markdown",
    { "type": "json",
      "prompt": "Extract: title, price (number), listPrice (number), currency, discountPercent (number), inStock (boolean), shippingCost, seller." }
  ]
}
```

Response adds `data.json` with those fields. **Verified live** on cloud:
a books test returned `{"title":"A Light in the Attic","price":51.77,"currency":"GBP","inStock":true}`.

**Important self-host caveat (verified):** the no-account self-host has no LLM
configured, so the `json` format returns **HTTP 500**. Two options:
1. **Default:** scrape `["markdown"]` and extract fields yourself (the agent is
   the LLM). Recommended — keeps self-host zero-config.
2. Set `OPENAI_API_KEY` (and `MODEL_NAME`) in the self-host compose to enable the
   `json` format there too. See `self-host-firecrawl/README.md`.

## curl quick reference

Self-host (no auth):

```bash
curl -s -X POST "$FIRECRAWL_API_URL/v2/scrape" \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com","formats":["markdown"],"onlyMainContent":true}'
```

Cloud (key from env — never inline a literal key):

```bash
curl -s -X POST "https://api.firecrawl.dev/v2/search" \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"query":"airpods pro buy","limit":5,"sources":["web"]}'
```

Or just use the bundled wrapper, which picks the backend for you (`$SKILL_DIR`
is this skill's own directory — see SKILL.md):

```bash
$SKILL_DIR/scripts/firecrawl.sh search "airpods pro buy" 5
$SKILL_DIR/scripts/firecrawl.sh scrape "https://www.noon.com/…/p/…"
```

## Token & cost discipline

- Small `limit`; scrape only finalists; `onlyMainContent: true`.
- Avoid `/crawl` and `/map` — they pull far more than a price comparison needs.
- On cloud, `creditsUsed` is in every response — watch it on big lists.
- Inline `scrapeOptions` on `/search` is convenient but multiplies credits; use
  deliberately, not by default.
