# temp example: simple order automation

> ⚠️ **The live AWS endpoints have been torn down** — the base URL below (`https://f50853np0i…`)
> no longer responds. The code, scripts, SuperFlows, and gitagent are all intact; re-run
> `bash infra/deploy.sh customagents` to recreate the stack (you'll get a **new** base URL — update
> it in `superflow-order-automation.json` and `gitagent/agent.yaml`/skill). `bash infra/teardown.sh customagents`
> removes everything again.

A throwaway example showing the **same workflow built two ways** — a Lyzr **SuperFlow** and a
**gitagent** — both driving the *same* real, public, zero-auth AWS endpoints.

## The flow
A customer places an order → check inventory for the SKU → if there's enough stock, place the
order → if not, **an AI step looks at the order history and decides how much to reorder**, restock
by that amount, then place the order → **if a restock was needed, push the delivery date out a few
days** (2 days when in stock, 5 when restocked).

The deterministic plumbing (HTTP calls, the in-stock/out-of-stock switch, delivery-date rules)
surrounds a single **AI reasoning node in the middle** — that contrast is the point of the demo.

## Endpoints (AWS API Gateway + Lambda + DynamoDB, us-east-1, public / no-auth) — *currently torn down*
Base URL when deployed: `https://f50853np0i.execute-api.us-east-1.amazonaws.com` *(no longer live — a
fresh `deploy.sh` issues a new URL)*. All resources are prefixed `temp-example-simple-order-automation-*`
and created by `infra/deploy.sh`.

| Method & path | Params (query **or** JSON body) | Returns |
|---|---|---|
| `GET /inventory/{sku}` | `?want=N` *(optional)* | `{sku, quantity, found}` — and with `?want`: `{want, sufficient:"yes"\|"no", shortfall}` |
| `GET /history/{sku}` | *(none)* | `{sku, stats:{orders, total_qty, avg_qty, max_qty}, orders:[…]}` — past orders for the AI to reason over |
| `POST /restock` | `sku`, `qty` | `{sku, added, quantity}` |
| `POST /orders` | `sku`, `qty`, `customer`, `delay_days?` (or `delivery_date?`) | `201 {order_id, delivery_date, inventory_remaining, ...}` or `409` if stock is insufficient |
| `POST /reset` | *(none)* | `{reset:true, inventory:[…seeded…], orders_cleared:N}` — reseed stock + wipe order history |

Design choices:
- **The backend is deliberately "dumb."** It serves data and does atomic operations; it does **not**
  decide *how much to reorder*. `/inventory?want=N` returns only the deterministic branch decision
  (`sufficient`, `shortfall`); `/history/{sku}` returns raw past-order data.
- **Smart History is AI logic in the middle of the deterministic flow.** When stock is short, the
  SuperFlow fetches `/history` and an **LLM node ("Reorder Planner")** reasons about the order
  history to choose the reorder quantity (`restock_qty` + a one-line `reason`) — then the
  deterministic restock/order steps resume. The gitagent does the same reasoning itself.
  This is the whole point of the example: a *Trigger → HTTP → Switch → **AI** → HTTP → HTTP* pipeline.
- **`POST /reset`** restores the seeded stock and clears all orders — a clean slate between demo runs.
- **Every endpoint accepts query params** (not only a JSON body), so the SuperFlow can drive them
  with templated-URL HTTP nodes — the confirmed-working node feature set.
- **`POST /orders` reserves stock atomically** (never oversells).

Seeded SKUs: `WIDGET-001` (50, in stock), `GADGET-002` (3, low), `GIZMO-003` (0, forces a restock).

## Contents
- `example.md` — **how to run it**: exact inputs for the SuperFlow, the gitagent, and raw curl (both scenarios)
- `infra/` — Lambda handlers (`inventory.mjs`, `history.mjs`, `restock.mjs`, `orders.mjs`, `reset.mjs`), `seed.json`, `deploy.sh`, `teardown.sh`
- `superflow-order-automation.json` — the **SuperFlow** build (import into Lyzr Studio → SuperFlow)
- `gitagent/` — the **gitagent** build (`agent.yaml`, `SOUL.md`, `RULES.md`, `DUTIES.md`, `skills/order-fulfillment/SKILL.md`, `memory/MEMORY.md`)

## Try it (curl)
```bash
B="https://f50853np0i.execute-api.us-east-1.amazonaws.com"

# in stock → order ships in 2 days
curl -s "$B/inventory/WIDGET-001?want=2"                         # sufficient:"yes"
curl -s -X POST "$B/orders?sku=WIDGET-001&qty=2&customer=acme&delay_days=2"

# out of stock → restock the (smart) suggested amount, then order (delayed 5 days)
curl -s "$B/inventory/GIZMO-003?want=5"                          # sufficient:"no", restock_qty (smart), history
curl -s -X POST "$B/restock?sku=GIZMO-003&qty=15"
curl -s -X POST "$B/orders?sku=GIZMO-003&qty=5&customer=acme&delay_days=5"

# clean slate between runs (reseed stock + wipe order history)
curl -s -X POST "$B/reset"
```

## Deploy / tear down
```bash
aws sso login --profile customagents     # browser; account 958216563951 (Lyzr-Custom-Agents)
bash infra/deploy.sh customagents        # idempotent; reseeds inventory; prints the API base URL
bash infra/teardown.sh customagents      # removes ONLY the temp-example-simple-order-automation-* resources
```
> The deploy/teardown scripts touch **only** resources named with the `temp-example-simple-order-automation-*`
> prefix — nothing else in the account is affected.
