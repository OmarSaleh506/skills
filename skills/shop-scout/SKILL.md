---
name: shop-scout
description: >-
  Comparison-shops any product across many online stores, finds the genuinely
  cheapest option after discounts, surfaces working coupons, and checks whether
  each seller is safe to buy from — for one product or a whole shopping list,
  any store, any region. Use this whenever the user wants to buy something
  online, asks where to buy a product or for the best/cheapest price, compares
  prices across stores (Noon, Amazon, Amazon.sa, Jarir, extra, Namshi,
  AliExpress, eBay, …), hunts for discount or promo codes (including first-order
  and social-media codes), asks whether a store/seller is legit or a scam, or
  hands over a shopping list to price out. It runs a 4-step pipeline per item —
  find sellers, rank by effective price (price − coupon + shipping), judge seller
  safety (Trusted / Mixed / Risky), and find working coupons — then prints a
  comparison table, a best-buy recommendation, and (for lists) a consolidated
  cart with a single-store bundle tip. Trigger even when the user does not say
  "shop-scout": e.g. "is aliexpress seller X legit", "cheapest place to buy a
  PS5 in Saudi", "find me a Noon coupon", "price-check these 5 things", or
  "compare prices for AirPods Pro". Not for building e-commerce or checkout
  features, stock or share prices, order tracking, or code review.
---

# shop-scout

Stop hopping between store tabs. Give shop-scout a **product** or a **shopping
list** and it will, for each item: find who sells it, rank sellers by the price
you'll *actually* pay after discounts and shipping, judge whether each seller is
safe, and dig up working coupons — then recommend the best buy and, across a
list, the smartest single-store bundle.

This skill is **agent-agnostic**. It assumes only three generic capabilities,
named however your runtime provides them:

- **web search** — issue a query, get back result URLs/titles/snippets.
- **fetch a URL** — retrieve a page's content as text/markdown.
- **run N tasks concurrently** — sub-agents where your runtime has them,
  otherwise just sequential or concurrent calls.

Quality depends heavily on *how* you fetch pages. Major retailers (Amazon.sa,
Noon, …) render prices with JavaScript and block naive fetchers. So shop-scout
prefers a real scraping backend (Firecrawl) and falls back to plain fetch only
when nothing better is configured. Read **Backend tiers** next — they are *not*
equivalent.

---

## Backend tiers (auto-detected — "use what you have")

Detect the backend in this exact order and announce which one you're using:

1. **`FIRECRAWL_API_URL` is set → self-hosted Firecrawl. ⭐ Recommended.**
   Your own Firecrawl (Docker) at that base URL. **No account, no API key, no
   quota** — and reliable extraction on JS-heavy stores. This is the setup that
   answers the usual objection to Firecrawl ("I don't want an account/quota").
   One-time setup is in `references/self-host-firecrawl/` (a `docker-compose.yml`
   you bring up with `docker compose up -d`, then
   `export FIRECRAWL_API_URL=http://localhost:3002`).
2. **Else if `FIRECRAWL_API_KEY` is set → Firecrawl cloud.**
   Base URL `https://api.firecrawl.dev/v2`, header `Authorization: Bearer fc-…`.
   Same endpoints as self-host, plus server-side structured (`json`) extraction.
   Subject to your plan's quota.
3. **Else → built-in web search + fetch. Best-effort fallback only.**
   Zero setup, but be honest about its limits: it hits bot walls and
   JS-rendered prices on major retailers and often returns weak or partial
   results. Use it, label the output as best-effort, and **suggest the
   self-hosted setup** for anything price-sensitive.

`SHOP_BACKEND` overrides detection: `auto` (default) | `firecrawl` (force
Firecrawl; requires URL or key) | `builtin` (force native fetch).

> Don't present the three tiers as equal in your output. If you ended up on
> built-in, say so and point the user at self-host. If on Firecrawl, just use it.

How to actually call Firecrawl (endpoints, params, the search-first-then-scrape
workflow, cloud vs self-host differences) lives in
**`references/firecrawl-usage.md`** — read it before your first Firecrawl call.
A ready-made wrapper, `$SKILL_DIR/scripts/firecrawl.sh`, auto-detects self-host
vs cloud from the same env vars and works from any agent that can run a shell
command.

> **`$SKILL_DIR`** — this skill's own directory (the folder containing this
> `SKILL.md`, `references/`, and `scripts/`). Resolve it per install: on a Claude
> Code plugin install it's `${CLAUDE_PLUGIN_ROOT}/skills/shop-scout`; for an
> `npx skills` / manual / other-agent install it's wherever this `SKILL.md`
> lives. Always reference bundled files through it, never a hardcoded path.

---

## Configuration (env vars — all optional, sane defaults)

| Var | Default | Meaning |
|---|---|---|
| `SHOP_BACKEND` | `auto` | `auto` \| `firecrawl` \| `builtin` |
| `FIRECRAWL_API_URL` | — | Self-host base URL, e.g. `http://localhost:3002`. Highest-priority backend. |
| `FIRECRAWL_API_KEY` | — | Firecrawl cloud key (`fc-…`). **Never write it to a file or commit it.** |
| `SHOP_SCOPE` | `both` | `saudi` \| `global` \| `both` — which store list to search. |
| `SHOP_STORES` | — | Comma list of pinned/preferred stores; *extends* the bundled lists. |
| `SHOP_PARALLEL` | `3` | Max products researched concurrently. Higher = faster **but more tokens and hits rate limits sooner**. |
| `SHOP_MAX_LISTINGS` | `5` | Max listings scraped per product (token control). |

Read env vars from the environment at runtime. A documented template lives in
`.env.example` — copy it to `.env`, fill values, and load it however your
runtime does (`.env` is gitignored). The store lists are in
`references/stores.md` and are meant to be edited.

---

## The 4-step pipeline (run per product)

For each product, do these four steps in order. Stay disciplined about tokens
(see **Token-efficiency rules**) — search broadly, scrape narrowly, extract
fields, never dump whole pages.

### Step 1 — Find sellers
Pick the store list from `SHOP_SCOPE` (+ any `SHOP_STORES`) — see
`references/stores.md`. Run **one** search per product where possible:
`"<product> buy"` (add `price` / store names when it sharpens results). Prefer
scoping to the target stores (e.g. `site:noon.com OR site:amazon.sa <product>`),
but also allow a general search so you don't miss a cheaper seller. Produce a
shortlist of candidate listing URLs, capped at `SHOP_MAX_LISTINGS`.

→ Firecrawl: `POST /search`. Built-in: your native web search.

### Step 2 — Compare price & discount
**Scrape only the top `SHOP_MAX_LISTINGS` listing URLs** from step 1. From each,
extract just these fields: **price**, **list/original price**, **discount %**,
**currency**, **in-stock**, **shipping cost / free-shipping threshold**, and the
**seller/merchant name** (important on marketplaces like Noon/Amazon/AliExpress
where third parties sell under one storefront).

Rank by **effective price = price − applicable coupon + shipping** (in one
currency; convert if the scope mixes regions and note the rate). A nominally
cheaper listing with paid shipping or no stock often loses.

→ Firecrawl: `POST /scrape` with `formats:["markdown"]`, `onlyMainContent:true`,
and `location.country` set to the store's region (e.g. `SA`). On **cloud** you
may add a `json` extraction format to get the fields back structured in one call
(see `references/firecrawl-usage.md`). On **self-host without an LLM key**, the
`json` format is unavailable — scrape markdown and extract the fields yourself.

### Step 3 — Judge seller safety
Give each shortlisted seller a verdict: **✅ Trusted / ⚠️ Mixed / ❌ Risky**,
with a **one-line reason** and — always — the **reference link(s) the verdict is
based on** (Trustpilot / Reddit / scam report / the listing's own rating page) so
the user can verify the risk rating themselves. A verdict with no source link is
incomplete — never ship one. Base it on:
- Reputation search: Trustpilot / Reddit / "<store or seller> scam / reviews /
  complaints". One focused search is usually enough.
- On-listing signals: seller rating, number of ratings, and a small sample of
  the **lowest-star reviews** (that's where fraud, fakes, and non-delivery show
  up) — read a few top and a few lowest, not all.
- Heuristics: brand-new seller + far-below-market price + no ratings = ❌.
  Established marketplace, high rating, many reviews, official/brand store = ✅.

Never invent a verdict — if you couldn't find enough signal, say "insufficient
data" rather than guessing.

### Step 4 — Find coupons
Hunt for codes that apply to the winning listing(s):
- **Coupon aggregators** and **the store's own** first-order / newsletter / app
  promos, plus **social media** (X/Twitter, Instagram bios, regional Telegram
  channels). Sources + search patterns are in `references/coupon-sources.md`.
For each code, print: the **copy-ready code**, **savings** (% or amount), **how
to apply it** (e.g. paste into the cart/checkout "Promo code" / "Coupon Code or
Gift Card" box; or "auto-applied via link"), **conditions** (first-order-only,
minimum spend, category limits, expiry), and a literal **"verify at checkout"** —
aggregator codes are frequently dead or conditional.
Fold a *confidently applicable* coupon into the effective price; keep speculative
ones in the coupon column only.

---

## Multi-product handling

**Input** can be: an inline list, a file (`shopping-list.md` / `.txt`, one item
per line, `#` comments ignored), or interactive (ask for items). If the user
gives a file path, read it.

**Fan out** up to `SHOP_PARALLEL` items at a time (default 3): run the 4-step
pipeline per item concurrently if your runtime supports it, else sequentially.
Higher parallelism is faster but burns tokens faster and trips rate limits
sooner — say so if the user asks to crank it up.

**Output for a list** = one comparison table per item **plus a consolidated cart
summary**:
- best store + coupon + effective price per item,
- a **grand total** (best-of-each),
- a **single-store bundle tip**: the one store that carries the most items —
  buying there can save on shipping and may let a store-wide coupon stack. Show
  its bundle total next to the best-of-each total so the trade-off is visible.

---

**Action-ready is the whole point.** Every option *and* the final pick must carry
everything the user needs to **buy without re-searching**:
1. the **direct product-page URL** (deep link to the item to buy — never just the
   store name);
2. **price · discount · effective price**, plus **stock & shipping**;
3. any coupon as a **copy-ready code** with **how/where to apply it** and its
   **conditions** (+ "verify at checkout");
4. the **seller-trust verdict with the reference link(s)** it's based on.

If a field is genuinely unavailable, write "n/a" — don't drop the column.

Per product, a markdown table, then a bolded recommendation:

```
### <product>  — backend: <self-host | cloud | built-in (best-effort)>
| Store | Price | Discount | Effective price | Stock / Shipping | Coupon (code · savings · how to apply · conditions) | Seller trust (+source) | Buy link |
|---|---|---|---|---|---|---|---|
| Noon | SAR 349 | -22% | **SAR 349** | In stock · free ship | `NEW15` · -15% · paste in cart "Coupon Code" box · first order, min SAR 200 · verify at checkout | ⚠️ Mixed ([Trustpilot](https://www.trustpilot.com/review/noon.com)) | [open product](https://www.noon.com/…/p/…) |
| … |

**Best buy: <store> — <effective price>.** <one-line why (cheapest after coupon, trusted, in stock)>
👉 Buy: <direct product URL>  ·  Coupon: `CODE` (apply in <where>)  ·  Trust: <verdict> (<source link>)
```

For a list, follow the per-item tables with:

```
## Cart summary
| Item | Best store | Effective price | Coupon (copy-ready) | Seller trust (+source) | Buy link |
| … |
**Grand total (best of each): <total>**
**Bundle tip: <store> carries N/M items → <bundle total>** (one shipment; store-wide code may stack) — bundle link if available.
```

Every row's **Buy link** is the direct product page. Use the local currency of
the scope; if mixing regions, normalize to one currency and note the rate.

---

## Token-efficiency rules (these keep runs cheap and fast)

- **Search broad, scrape narrow.** One search per product where possible, then
  scrape only the top `SHOP_MAX_LISTINGS`.
- **Extract fields, never dump pages.** Pull the named fields; summarize. Don't
  paste HTML or full markdown into your reasoning or output.
- **Cap reviews.** A few top + a few lowest-star per seller — enough to spot
  red flags, not a transcript.
- **Reuse, don't re-fetch.** If two items share a store, reuse what you learned
  about that store's trust and coupons.
- **Respect `SHOP_MAX_LISTINGS` and `SHOP_PARALLEL`.** They exist to bound cost.

---

## Feasibility honesty (tell the user the truth)

Steps 2 (live prices) and 4 (coupons/social) are **best-effort**, especially on
built-in fetch. Bot walls, JS-rendered prices, gated X/Twitter access, and
SEO-spam coupon sites full of dead codes are *normal*, not bugs. So:

- **Show source links and never invent** a price, discount, stock status, seller
  rating, or coupon code. If you couldn't get a field, write "n/a" and say why.
- **End every coupon with "verify at checkout."**
- If you're on built-in and prices look blocked or stale, **say so** and
  recommend the self-hosted Firecrawl setup (it materially improves Step 2).

## Be a good web citizen

This skill reads public pages for personal comparison shopping. Respect each
site's Terms of Service and `robots.txt`, don't hammer sites (the parallelism
caps help), and prefer official or affiliate product APIs where a store offers
one. Don't use this to bypass paywalls, logins, or anti-bot measures.

---

## Reference files

- `references/firecrawl-usage.md` — how to call Firecrawl (search/scrape/interact,
  params, response shapes, cloud vs self-host). **Read before your first call.**
- `references/stores.md` — Saudi + global starter store lists (editable);
  how `SHOP_SCOPE` and `SHOP_STORES` combine.
- `references/coupon-sources.md` — coupon aggregators + first-order &
  social-media search patterns.
- `references/self-host-firecrawl/` — `docker-compose.yml` (api + worker ×2 +
  redis + rabbitmq + postgres + playwright) and a `README.md` to run it and set
  `FIRECRAWL_API_URL`.
- `$SKILL_DIR/scripts/firecrawl.sh` — env-driven `/search` and `/scrape` wrapper
  (auto-detects self-host vs cloud). Optional but handy from any shell-capable agent.
