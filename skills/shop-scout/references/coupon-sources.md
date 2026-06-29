# Coupon sources & search patterns

Where to look for working codes in Step 4, and how to phrase the searches.
Coupons are the noisiest part of shopping research: aggregators are full of dead
or conditional codes and SEO spam. So treat every code as a *candidate* until
proven — always end with **"verify at checkout."**

## Three places codes hide

1. **The store itself** — the highest-quality source. Look for:
   - **First-order / newsletter / app** promos ("get 10% off your first order",
     "SAR 25 off when you sign up", app-only prices).
   - On-site banners, the cart/checkout promo box, and the store's "offers" page.
2. **Coupon aggregators** — broad but unreliable; cross-check savings/expiry.
3. **Social media** — often where *current* codes (esp. influencer / first-order)
   actually live.

## Aggregators

**Global:** RetailMeNot (`retailmenot.com`), Coupons.com, Honey (`joinhoney.com`),
Slickdeals (`slickdeals.net`), Wethrift (`wethrift.com`), CouponBirds.

**Saudi / MENA:** Almowafir (`almowafir.com`), Picodi (`picodi.com/sa`),
CouponKSA (`couponksa.com`), Wadi/Discountcode sites, Telegram coupon channels
(very common in KSA — see below).

## Social media patterns

- **X / Twitter:** search `<store> coupon`, `<store> promo code`, `<store> كود خصم`.
  Sort by **Latest**. Brand accounts and deal accounts post time-boxed codes.
  Access may be gated/limited — if you can't read results, say so, don't invent.
- **Instagram:** brand and influencer **bios** and recent posts/stories often
  carry a personal first-order code (`"<influencer> code <store>"`).
- **Telegram (KSA-popular):** public coupon channels aggregate KSA codes; search
  `<store> coupon telegram` / `كوبون <store>`.

## Search-query templates

Swap `<store>`/`<product>` in. Run the cheapest, most specific one first.

```
<store> coupon code
<store> promo code <current month> <year>
<store> first order discount
<store> كود خصم            # Arabic: "discount code"
<store> كوبون              # Arabic: "coupon"
<product> discount code <store>
site:almowafir.com <store>
<store> coupon twitter / telegram
```

## What to record per code

| Field | Example |
|---|---|
| Code | `NEW15` |
| Savings | `-15%` or `SAR 25 off` |
| Conditions | first-order-only · min spend SAR 200 · electronics excluded · expires 2026-07-15 |
| Source | link to where you found it |
| Classification | `✅ applicable` / `❔ unknown` / `❌ not applicable` (see below) |
| Status | **"verify at checkout"** (always) |

## Classify before you fold a code into effective price

This is the rule that keeps the recommended winner stable — a coupon you *can't
actually use* must never lower a price. Apply the same test the SKILL's Step 4
defines:

- **✅ applicable** — *every* condition checks out: not expired, min-spend ≤ this
  cart, category matches the product, and (if first-order-only) the user is
  genuinely new. **Only these reduce effective price.**
- **❔ unknown** — any one condition can't be verified (no expiry shown, unclear
  minimum, "selected items" with no list). Keep it in the coupon column as an
  FYI; never fold it into effective price.
- **❌ not applicable** — a condition is known to fail. Drop it.

**Stacking:** never stack codes. Apply a single code unless the store's own T&Cs
state stacking is allowed — and then link that T&C in the source field.
