# Skill: order-fulfillment

Fulfill a customer order against the live inventory API. Inputs: `sku`, `qty`, `customer`.

All commands assume `API_BASE` is set (see `agent.yaml`):

```bash
API_BASE="https://f50853np0i.execute-api.us-east-1.amazonaws.com"
```

## Step 1 — Check inventory (and get the decision)

Ask the API both "how much do we have" and "is that enough for `qty`" in one call. The `?want=`
query makes the endpoint return the decision so you don't compute it yourself.

```bash
curl -s "$API_BASE/inventory/$SKU?want=$QTY"
# => {"sku":"GIZMO-003","quantity":0,"found":true,"want":5,
#     "sufficient":"no","shortfall":5,"restock_qty":15}
```

Branch on `sufficient`:
- `"yes"` → go to **Step 3** with `delay_days=2`.
- `"no"`  → do **Step 2** (restock by `restock_qty`), then **Step 3** with `delay_days=5`.

## Step 2 — Restock (only if short)

Use the `restock_qty` the check returned — not a number you made up.

```bash
curl -s -X POST "$API_BASE/restock?sku=$SKU&qty=$RESTOCK_QTY"
# => {"sku":"GIZMO-003","added":15,"quantity":15}
```

## Step 3 — Place the order

`delay_days` encodes the honest delivery promise: `2` for in-stock, `5` when a restock was needed.

```bash
curl -s -X POST "$API_BASE/orders?sku=$SKU&qty=$QTY&customer=$CUSTOMER&delay_days=$DELAY"
# 201 => {"order_id":"ord_56fad7f4","sku":"GIZMO-003","qty":5,"customer":"acme",
#         "delivery_date":"2026-06-20","status":"placed","inventory_remaining":10, ...}
```

- `201` → success. Report `order_id`, qty, whether a restock happened, and `delivery_date`.
- `409` → `{"error":"insufficient stock"}`. Stock changed under you (someone else ordered). Stop;
  do **not** loop. Report that the order could not be reserved.

## Worked examples

**In stock (`WIDGET-001`, qty 2):** check → `sufficient:"yes"` → order `delay_days=2` →
delivery ≈ today+2. No restock.

**Out of stock (`GIZMO-003`, qty 5):** check → `sufficient:"no"`, `restock_qty:15` →
restock 15 → order `delay_days=5` → delivery ≈ today+5. Tell the customer it's delayed.

## Notes
- Endpoints are public, no auth, no headers needed.
- `/orders` reserves stock atomically — it is the single source of truth for "did it sell".
- Seeded SKUs: `WIDGET-001` (in stock), `GADGET-002` (low: 3), `GIZMO-003` (empty: 0).
