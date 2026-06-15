# temp example: simple order automation

A throwaway example showing the **same workflow built two ways** — a Lyzr **SuperFlow** and a
**gitagent** — both driving the *same* real, public, zero-auth AWS endpoints.

## The flow
A customer places an order → check inventory for the SKU → if there's enough stock, place the
order → if not, restock to add stock, then place the order → **if a restock was needed, push the
delivery date out a few days** (2 days when in stock, 5 when restocked).

## Live endpoints (AWS API Gateway + Lambda + DynamoDB, us-east-1, public / no-auth)
Base URL: `https://f50853np0i.execute-api.us-east-1.amazonaws.com`
All resources are prefixed `temp-example-simple-order-automation-*` and created by `infra/deploy.sh`.

| Method & path | Params (query **or** JSON body) | Returns |
|---|---|---|
| `GET /inventory/{sku}` | `?want=N` *(optional)* | `{sku, quantity, found}` — and with `?want`: `{want, sufficient:"yes"\|"no", shortfall, restock_qty, buffer, history}` |
| `POST /restock` | `sku`, `qty` | `{sku, added, quantity}` |
| `POST /orders` | `sku`, `qty`, `customer`, `delay_days?` (or `delivery_date?`) | `201 {order_id, delivery_date, inventory_remaining, ...}` or `409` if stock is insufficient |
| `POST /reset` | *(none)* | `{reset:true, inventory:[…seeded…], orders_cleared:N}` — reseed stock + wipe order history |

Design choices that keep both builds simple:
- **The decision lives in `/inventory?want=N`** — it returns `sufficient` and `restock_qty`, so the
  orchestrator just branches on a string and never does its own math/date logic.
- **Smart History reorder.** When stock is short, `restock_qty` isn't a flat buffer — `/inventory`
  scans the SKU's past orders and sizes the reorder from real demand (`shortfall + max(10, avg_order_qty × 3)`),
  so high-velocity SKUs get restocked deeper. With no history it falls back to a flat buffer of 10.
  The response includes `buffer` and `history:{orders, total_qty, avg_qty}` for transparency.
- **`POST /reset`** restores the seeded stock and clears all orders — a clean slate between demo runs.
- **Every endpoint accepts query params** (not only a JSON body), so the SuperFlow can drive them
  with templated-URL HTTP nodes — the confirmed-working node feature set.
- **`POST /orders` reserves stock atomically** (never oversells). The orchestration
  (check → restock → order → delivery-date) lives in the SuperFlow / gitagent, not the endpoints.

Seeded SKUs: `WIDGET-001` (50, in stock), `GADGET-002` (3, low), `GIZMO-003` (0, forces a restock).

## Contents
- `example.md` — **how to run it**: exact inputs for the SuperFlow, the gitagent, and raw curl (both scenarios)
- `infra/` — Lambda handlers (`inventory.mjs`, `restock.mjs`, `orders.mjs`, `reset.mjs`), `seed.json`, `deploy.sh`, `teardown.sh`
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
