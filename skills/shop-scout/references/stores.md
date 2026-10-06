# Store lists

Starter lists shop-scout searches, grouped by region. **Edit these freely** —
add the stores you actually buy from, remove ones you don't. They're plain
markdown so anyone (or any agent) can maintain them.

## How scope + pins combine

- `SHOP_SCOPE=saudi` → search the **Saudi** list. `global` → the **Global**
  list. `both` (default) → the union.
- `SHOP_STORES` (comma list) is **added on top** of whatever scope selects, and
  takes priority in ties. Example: `SHOP_STORES="noon.com,amazon.sa,jarir.com"`.
- Use the **domain** in `site:` filters to scope a search to a store, e.g.
  `site:amazon.sa airpods pro`.

A store being listed doesn't guarantee it stocks an item or that its prices are
scrapable — it's a starting set of *where to look*.

## Saudi Arabia (`SHOP_SCOPE=saudi`)

| Store | Domain | Notes |
|---|---|---|
| Noon | `noon.com` (`/saudi-en`) | Major KSA/UAE marketplace; 1st-party + 3rd-party sellers. Check seller per listing. |
| Amazon.sa | `amazon.sa` | Saudi Amazon; "Sold by" + "Ships from" matter for trust. |
| Jarir | `jarir.com` | Electronics, books, office; trusted retail chain. |
| extra | `extra.com` | Electronics & appliances; frequent installment/bundle promos. |
| Namshi | `namshi.com` | Fashion, footwear, beauty. |
| AliExpress | `aliexpress.com` | Cross-border; cheap but seller trust varies a lot — lean on Step 3. |

Other KSA options worth adding by hand if relevant: **Carrefour KSA**
(`carrefourksa.com`), **BinDawood / Danube** (groceries), **Saco**
(`saco.sa`, hardware/home), **Golden Scent** (`goldenscent.com`, beauty),
**Trendyol** (`trendyol.com`). (Xcite is Kuwait-based, not KSA; Wadi has shut down.)

## Global (`SHOP_SCOPE=global`)

| Store | Domain | Notes |
|---|---|---|
| Amazon | `amazon.com` | Watch "Sold by"/"Ships from"; third-party sellers vary. |
| eBay | `ebay.com` | New + used; check seller feedback % and item condition. |
| AliExpress | `aliexpress.com` | Cross-border; seller trust varies. |
| Walmart | `walmart.com` | 1st-party + marketplace. |
| Best Buy | `bestbuy.com` | Electronics; price-match policies. |
| Newegg | `newegg.com` | PC/components; marketplace sellers vary. |
| B&H | `bhphotovideo.com` | Photo/AV/electronics; strong reputation. |

These starter lists are examples, not a limit: shop-scout works in any region.
Add your own country's retailers by domain (Saudi is just the bundled example).
Region-specific giants to add as needed: **Amazon.ae / .co.uk / .de**,
**Flipkart** (India), **Jumia** (Africa), **MediaMarkt** (EU), **Xcite** (Kuwait).

Domains were spot-checked 2026-10 (reachable); some sites (B&H, Trendyol) return
403 to plain fetchers — that's a bot wall, not a dead store. Store-specific path
hints like `/saudi-en` change over time; rely on the bare domain.

## Maintaining this file

- One row per store; keep the **domain** accurate (it powers `site:` scoping).
- Group by region so `SHOP_SCOPE` stays meaningful.
- If you almost always buy from a fixed set, put them in `SHOP_STORES` so they're
  searched first regardless of scope.
