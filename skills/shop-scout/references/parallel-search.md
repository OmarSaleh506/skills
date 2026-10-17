# Optional search and fetch with Parallel MCP

If your agent has no web search or page-fetch tool, you can supply those
capabilities with [Parallel Search MCP](https://docs.parallel.ai/integrations/mcp/search-mcp).
It offers free web search and page fetching without an account or API key;
anonymous search uses Fast mode and is subject to rate limits.

This is an optional tool setup for the existing **built-in** research path,
not a new `SHOP_BACKEND` value. Firecrawl detection and explicit backend choices
still apply. Parallel does not remove shop-scout's summary-only rule for the
built-in path or guarantee readable live prices on JS-heavy stores.

## Connect your agent

In Claude Code, run this from the project where you use shop-scout:

```bash
claude mcp add --transport http "Parallel-Search-MCP" https://search.parallel.ai/mcp
claude mcp get "Parallel-Search-MCP"
```

If that server name already exists, inspect it first with `claude mcp get`
and keep your existing configuration unless you choose to change it. In a
Claude Code session, use `/mcp` to check the connection and approve the tools
when prompted. You should see `web_search` and `web_fetch` (your runtime may
prefix their names with the server name).

For other MCP-capable agents, add `https://search.parallel.ai/mcp` using their
**Streamable HTTP** transport. Choose no authentication for this anonymous
endpoint. Client-specific setup is in the
[installation guide](https://docs.parallel.ai/integrations/mcp/search-mcp#installation).
Keep other configured servers and credentials intact. If your runtime cannot
connect to MCP, skip this optional setup and use its native search/fetch tools;
if neither is available, say research is unavailable rather than invent results.

## Use it with shop-scout

To try this path explicitly, set `SHOP_BACKEND=builtin` in the environment
before launching your agent. Otherwise leave your backend settings as they are;
configuring MCP does not override a Firecrawl URL, key, or backend choice.

For example, ask:

> Use shop-scout to research Sony WH-1000XM5 sellers in Saudi Arabia. For this
> built-in run, use Parallel's search and fetch tools. Give the honest research
> summary with direct product links and sourced seller-safety notes. Do not
> print a comparison table or treat a search snippet as a verified live price.

Map the tools to the existing pipeline:

| Pipeline task | Parallel tool | What to pass and retain |
|---|---|---|
| Find sellers (Step 1) | `web_search` | Set `objective` to finding the exact model/variant and `search_queries` to the scoped store query from Step 1. Keep direct listing URLs and source excerpts. Apply the same fallback, de-duplication, priority order and listing cap. |
| Read shortlisted listings (Step 2) | `web_fetch` | Pass the selected product URLs in `urls`, with a focused `objective` for model, price, seller, stock and shipping. Keep a source URL for every fact; blocked or absent fields stay unknown. |
| Seller reputation and coupons (Steps 3–4) | `web_search`, then `web_fetch` when needed | Search for the specific seller or coupon terms. Fetch pages when excerpts are insufficient. Retain source links and apply the existing seller-safety and coupon-applicability checks. |

Fetch only the shortlisted listings, respecting `SHOP_MAX_LISTINGS` and
`SHOP_PARALLEL`. Prefer excerpts over full-page content. If you supply the
optional `session_id`, reuse one value across related searches and fetches in
the same conversation.

The built-in **data-floor gate still requires an honest research summary**,
including the existing Enable Firecrawl block. Search snippets and aggregator
prices are indicative, not verified store reads. Do not infer free shipping,
stock, coupon applicability or a seller verdict from missing data. If a tool
fails or reaches its limit, report the gap and summarize only the evidence
already obtained; do not retry repeatedly or change session IDs to evade limits.
