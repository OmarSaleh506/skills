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
   Zero setup, but it hits bot walls and JS-rendered prices on major retailers
   and can't reliably read live prices. On this backend you **do not print a
   comparison table** — you output the **honest research summary** (see
   **Output: decide the format first**) and point the user at Firecrawl.

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

### Step 1 — Find sellers (deterministic selection)
The seller set **and its order must be reproducible**: same inputs → same
shortlist → same row order, every run. The friend who called this skill
"different every time" was hitting an unstable seller set. Follow these rules
exactly — they are what fix it:

1. **Scoped search first.** Build the store list from `SHOP_SCOPE` (+ any
   `SHOP_STORES`) — see `references/stores.md` — and search *scoped to those
   domains*: `site:noon.com OR site:amazon.sa OR … <product>`. One scoped search
   per product where possible.
2. **One general fallback, only if thin.** If the scoped search returns fewer
   than `SHOP_MAX_LISTINGS` distinct in-list sellers, run **exactly one**
   unscoped search (`"<product> buy"`) to catch a seller you'd otherwise miss.
   Do **not** keep firing extra searches to "find a cheaper one" — that is what
   makes the seller set (and the winner) drift between runs.
3. **De-duplicate by seller.** One listing per seller — the canonical product
   page. If a seller appears more than once, keep the first by the order below.
4. **Fixed priority / tie-break order** (this is also the output row order):
   1. pinned `SHOP_STORES`, **in the order the user listed them**;
   2. official / first-party listings (the brand's own store, or "sold by
      <Store>" where the marketplace itself is the merchant);
   3. all other sellers.
   Tier 1 is ordered by the user's pin order. Tiers 2 and 3 have no user-given
   order, so within each, sort by **domain alphabetically** — never by search
   rank or by price (both jitter run-to-run, and ordering by them is the bug).
5. **Cap deterministically.** After ordering, take the first `SHOP_MAX_LISTINGS`
   and drop the rest. Don't reshuffle later.

The result is a fixed, ordered shortlist of candidate listing URLs. Steps 2–4
only *enrich* these rows — the **row set and order never change** after Step 1.

→ Firecrawl: `POST /search`. Built-in: your native web search.

### Step 2 — Compare price & discount
**Scrape only the top `SHOP_MAX_LISTINGS` listing URLs** from step 1. From each,
extract just these fields: **price**, **list/original price**, **discount %**,
**currency**, **in-stock**, **shipping cost / free-shipping threshold**, and the
**seller/merchant name** (important on marketplaces like Noon/Amazon/AliExpress
where third parties sell under one storefront).

Rank by **effective price = price − applicable coupon + shipping**, in a single
currency. "Applicable" is the strict Step-4 sense — only a coupon classified
**✅ applicable** reduces effective price. If the scope mixes regions and you
must convert, **pin one FX source and stamp it** — e.g. `FX: 1 USD = 3.75 SAR
(google.com/finance, <date>)` — and use that one rate for the entire run, so the
ranking can't flip on a second lookup. A nominally cheaper listing with paid
shipping or no stock often loses.

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

### Step 4 — Find coupons (with a strict applicability test)
Hunt for codes that apply to the shortlisted listing(s) via **coupon
aggregators**, **the store's own** first-order / newsletter / app promos, and
**social media** (X/Twitter, Instagram bios, regional Telegram channels). Sources
and search patterns are in `references/coupon-sources.md`.

**Classify every code before it can touch effective price** — this is what stops
the winner from flipping on a coupon you can't actually use:

- **✅ applicable** — *all* of: not expired, min-spend ≤ this cart, category
  matches the product, and (if first-order-only) the user is actually new. Only
  **applicable** codes are folded into effective price.
- **❔ unknown** — any single condition can't be verified (no expiry shown,
  unclear min-spend, "selected items" with no list). Show it in the coupon
  column as an FYI; **never** fold it into effective price.
- **❌ not applicable** — a condition is known to fail (expired, min-spend above
  cart, wrong category, first-order-only for a returning user). Don't show it.

For each code you show, print: the **copy-ready code**, **savings** (% or
amount), **how to apply** (e.g. paste into the cart/checkout "Promo code" /
"Coupon Code or Gift Card" box, or "auto-applied via link"), its **conditions**,
its **classification**, and a literal **"verify at checkout"** — aggregator codes
are frequently dead.

**Stacking:** never assume two codes stack. Apply only one unless the store's own
T&Cs state stacking is allowed — and then link that T&C.

---

## Multi-product handling

**Input** can be: an inline list, a file (`shopping-list.md` / `.txt`, one item
per line, `#` comments ignored), or interactive (ask for items). If the user
gives a file path, read it.

**Fan out** up to `SHOP_PARALLEL` items at a time (default 3): run the 4-step
pipeline per item concurrently if your runtime supports it, else sequentially.
Higher parallelism is faster but burns tokens faster and trips rate limits
sooner — say so if the user asks to crank it up.

**Output for a list** = one comparison table (or honest summary, per the gate
below) per item, **plus a consolidated cart summary** with a grand total and a
single-store bundle tip. The exact layout is pinned in **Worked example 2**
under the output contract.

---

## Output: decide the format first

Before writing anything, run the **data-floor gate**. It decides whether you've
earned a comparison table or must degrade to an honest summary — this is the gate
that stops shop-scout from ever printing a fake, made-up table:

- **Built-in backend → always the honest summary, never a table.** Built-in fetch
  can't reliably read prices off JS-heavy stores, so a table built on it would be
  fiction. (This was the #1 reason past runs looked "stupid.")
- **Firecrawl backend (self-host or cloud):** a price comparison is only
  meaningful if you actually read prices. Count the shortlisted listings from
  Step 1: if **half or more** have **no real price** (blocked, `n/a`, or never
  loaded), degrade to the honest summary. Otherwise, print the **comparison
  table**. (Stock and shipping *enrich* the table but don't gate it — a missing
  stock value just becomes `n/a` in its column; only missing **prices** sink the
  table, because price is the whole comparison.)

A short honest summary always beats a confident fake table.

### A) Honest research summary (degraded mode)

Use this whenever the gate says "no table." Be useful and truthful — no invented
prices, no fabricated verdicts:

- **What it is** — the product, plus any spec you actually pinned down.
- **Where to buy** — the candidate seller links you found (direct product URLs
  where you have them), as a plain list.
- **Real prices obtained** — *only* prices you actually read, each labelled with
  its source link. Got none? Say so: "no live prices could be read on this
  backend."
- **Seller-safety notes** — only verdicts you can back with a source link; skip
  the rest.

Then append the upgrade block **verbatim**. This is the one place it's defined —
reuse it wherever the honest summary is shown:

> **⚡ Want real price comparison? Enable Firecrawl** — built-in fetch is blocked
> by big stores, so it can't read live prices.
> - **Recommended — self-host (no account, no quota):** in
>   `references/self-host-firecrawl/`, run `docker compose up -d`, then
>   `export FIRECRAWL_API_URL=http://localhost:3002` and re-run shop-scout.
> - **Or cloud (free tier):** create an account at <https://www.firecrawl.dev> →
>   Dashboard → **API Keys** → copy the `fc-…` key →
>   `export FIRECRAWL_API_KEY=fc-…` and re-run shop-scout.

### B) Comparison table contract (only when the data floor is met)

This layout is a **contract, not a suggestion** — same columns, same order, every
run. Don't add, drop, reorder, or rename columns. Every row carries everything
needed to **buy without re-searching**. Fill each column exactly per this schema:

| Column | Format (fill exactly like this) |
|---|---|
| **Store** | the actual seller / merchant name (not just the marketplace) |
| **Price** | currency **+** amount, always — `SAR 349` (never a bare number) |
| **Discount** | `-22%` only if the list price is known, else `n/a` (don't compute one you can't source) |
| **Effective price** | `price − applicable coupon + shipping`, same currency, **bold** — `**SAR 312**` |
| **Stock / Shipping** | stock enum + shipping; stock ∈ {`In stock`, `Low stock (N)`, `Out of stock`, `n/a`} |
| **Coupon** | `CODE · savings · how to apply · conditions · classification · verify at checkout`, or `none found` |
| **Seller trust** | enum + one-line reason + **source link**; trust ∈ {`✅ Trusted`, `⚠️ Mixed`, `❌ Risky`} — a verdict with no link is invalid |
| **Buy link** | direct **product-page** URL (deep link to the item), never the store homepage |

**Rows appear in the Step-1 priority order** (pinned → first-party → others,
alphabetical within a tier) — **not** sorted by price. The cheapest option is
named in the **recommendation line**, never by reordering the table. (Sorting a
table by a price that jitters between runs is exactly what made past runs look
different every time.)

#### Worked example 1 — single product

Backend: self-host. `SHOP_STORES="noon.com,amazon.sa"`, scope `saudi`. Rows are
in priority order — pinned stores first **in the pinned order** (Noon, then
Amazon.sa), then others alphabetically (Jarir). Note the winner is **not** the
top row; it's named in the recommendation line, not by reordering the table:

```
### Sony WH-1000XM5 — backend: self-host
| Store | Price | Discount | Effective price | Stock / Shipping | Coupon | Seller trust | Buy link |
|---|---|---|---|---|---|---|---|
| Noon | SAR 1,399 | -13% | **SAR 1,399** | In stock · free ship | none found | ✅ Trusted — major KSA marketplace, 4.5★ / 12k ratings ([Trustpilot](https://www.trustpilot.com/review/noon.com)) | [open product](https://www.noon.com/…/p/…) |
| Amazon.sa | SAR 1,420 | n/a | **SAR 1,370** | In stock · free ship | `SAVE50` · -SAR 50 · paste in checkout "Promo code" box · no min spend · ✅ applicable · verify at checkout | ✅ Trusted — sold & shipped by Amazon.sa ([listing](https://www.amazon.sa/…/dp/…)) | [open product](https://www.amazon.sa/…/dp/…) |
| Jarir | SAR 1,449 | n/a | **SAR 1,449** | Low stock (3) · free ship | none found | ✅ Trusted — established KSA retail chain ([Trustpilot](https://www.trustpilot.com/review/jarir.com)) | [open product](https://www.jarir.com/…) |

**Best buy: Amazon.sa — SAR 1,370.** Cheapest after the SAR 50 coupon, in stock, sold directly by Amazon.
👉 Buy: https://www.amazon.sa/…/dp/…  ·  Coupon: `SAVE50` (paste in checkout "Promo code" box)  ·  Trust: ✅ Trusted ([source](https://www.amazon.sa/…/dp/…))
```

#### Worked example 2 — a 3-item shopping list

Each item gets its own table as in example 1 (omitted here for brevity), then a
single consolidated cart:

```
## Cart summary
| Item | Best store | Effective price | Coupon (copy-ready) | Seller trust (+source) | Buy link |
|---|---|---|---|---|---|
| Sony WH-1000XM5 | Amazon.sa | SAR 1,370 | `SAVE50` | ✅ Trusted ([src](https://www.amazon.sa/…)) | [buy](https://www.amazon.sa/…/dp/…) |
| Logitech MX Master 3S | Noon | SAR 349 | none found | ✅ Trusted ([src](https://www.trustpilot.com/review/noon.com)) | [buy](https://www.noon.com/…/p/…) |
| Anker 737 power bank | Amazon.sa | SAR 379 | none found | ✅ Trusted ([src](https://www.amazon.sa/…)) | [buy](https://www.amazon.sa/…/dp/…) |

**Grand total (best of each): SAR 2,098**
**Bundle tip: Amazon.sa carries 2 / 3 items → SAR 1,749 for those two** (one shipment; a store-wide code *may* stack — verify at checkout). Buy Sony + Anker from Amazon.sa, Logitech from Noon.
```

Use the local currency of the scope; if mixing regions, normalize to the one
pinned FX rate (Step 2) and show it once.

### Pre-output validation gate (run this before you print)

Walk this checklist — it's a hard gate, not advice. It converts "don't invent"
from a hope into an enforced step:

- [ ] **Format** — did the data-floor gate pass? If not, you're printing the
      honest summary, not a table.
- [ ] **Per row** has all three of: a **price with a source**, a **trust verdict
      with a source link**, and a **direct product-page buy link**. A row missing
      any one is **dropped** — don't pad it with `n/a` and keep it.
- [ ] **No invention** — every price, discount, stock value, trust verdict, and
      coupon code traces to something you actually read. Can't source it → it's
      not in the output.
- [ ] **Coupons** — only **✅ applicable** codes are in effective price; `❔
      unknown` ones are FYI-only in the coupon column; no unverified stacking.
- [ ] **Thin results** — if fewer than ~3 sellers survive the gate, say so plainly
      ("only N sellers had readable prices") so the user knows it's partial.

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

Steps 2 (live prices) and 4 (coupons/social) are **best-effort**. Bot walls,
JS-rendered prices, gated X/Twitter access, and SEO-spam coupon sites full of
dead codes are *normal*, not bugs. The **data-floor gate** and **pre-output
validation gate** above are how this skill stays honest about that: when the data
isn't there, it degrades to a research summary instead of inventing a table, and
it never ships a price, verdict, or code it couldn't source. Every coupon still
ends with "verify at checkout."

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
