# Buying notes: cross-border costs and "is this a real discount?"

Read when a listing ships from another country, or when a headline discount
looks too good. These notes refine Step 2; they never override the output
contract (row order, effective-price formula, in-stock-only winner, no invented
values).

## Cross-border purchases

Effective price must reflect what the user actually pays at their door. For a
listing that ships internationally, check the checkout or product page for:

- **Currency** — convert with the single pinned FX rate (SKILL.md Step 2). Note
  that card issuers often add a foreign-transaction fee; mention it, don't
  silently bake in a guess.
- **VAT / sales tax** — is the displayed price tax-inclusive? Local stores
  usually show tax-inclusive prices; many foreign stores show pre-tax prices.
  Compare like with like. If you can't tell, say `tax: unclear` in the row.
- **Import duty / customs** — may apply to cross-border orders above the
  destination country's de-minimis threshold. Thresholds and rates are
  country-specific and change; **look up the user's country's current rules
  rather than quoting numbers from memory**, and if you can't source them,
  flag "import duty may apply" instead of computing a figure.
- **Shipping and delivery time** — a far cheaper overseas price with a
  multi-week delivery and costly returns is a different product from a local
  next-day one. Mention delivery time and return policy alongside price.
- **Warranty** — grey-market or foreign-region units may not be covered by the
  local manufacturer warranty or may use a different plug/voltage/language.

Only add duty/tax/fees to effective price when you read a sourced figure; an
unsourced estimate goes in a note beside the table, not in the number.

## Is this a real discount?

A struck-through "was" price is the store's own claim. Sanity-check before
trusting a `Discount` value:

- Prefer the **price you can actually read now** over the percentage. Rank on
  effective price, never on discount %.
- Look for an independent history (a price-tracker site for that store, or the
  store's own "lowest price in 30 days" statement where the law requires one).
  If the current price equals its usual price, the discount is cosmetic.
- Red flags: a list price that no other store has ever charged, a "was" price
  far above the manufacturer's MSRP, countdown timers that reset, a "sale"
  that has run for months.
- Sale events (Black Friday, White Friday, 11.11, national-day sales) are real
  but often match prices available at other times; note an upcoming event if
  the user isn't in a hurry.

If no history is available, leave `Discount` as shown only when the list price
is on the page, and don't assert the deal is genuine. Never invent a history.
