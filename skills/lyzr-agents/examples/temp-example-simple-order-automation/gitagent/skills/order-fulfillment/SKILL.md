---
name: order-fulfillment
description: Fulfill a customer order against the live inventory API — check stock, and when short, reason over order history to decide the reorder amount, restock, place the order, and set the delivery date. Use for any order/inventory/restock/reset request.
confidence: 1
usage_count: 3
success_count: 3
failure_count: 0
negative_examples: []
---

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
# => {"sku":"GIZMO-003","quantity":0,"found":true,"want":5,"sufficient":"no","shortfall":5}
```

The backend only returns the **deterministic** decision (`sufficient`, `shortfall`). It does NOT
tell you how much to reorder — that's your job (you're the AI). Branch on `sufficient`:
- `"yes"` → go to **Step 3** with `delay_days=2`.
- `"no"`  → do **Step 2** (decide + restock), then **Step 3** with `delay_days=5`.

## Step 2 — Reorder reasoning + restock (only if short)

This is the smart step. First pull the SKU's order history, then **reason** about how much to reorder:

```bash
curl -s "$API_BASE/history/$SKU"
# => {"sku":"GIZMO-003","stats":{"orders":3,"total_qty":24,"avg_qty":8,"max_qty":8},
#     "orders":[{"order_id":"...","qty":8,"customer":"acme","created_at":"..."}, ...]}
```

Decide `restock_qty` from the data:
- It MUST cover the `shortfall` (the units missing for this order).
- Add safety stock for expected near-future demand: a good target is `shortfall + ~3 × avg_qty`.
- If there's little/no history (`avg_qty` ~0), use a small flat buffer (~10): `shortfall + 10`.
- Keep it sensible — don't over-order wildly. Note your reasoning (cite shortfall + avg order size).

Then restock by the amount you chose:
```bash
curl -s -X POST "$API_BASE/restock?sku=$SKU&qty=$RESTOCK_QTY"
# => {"sku":"GIZMO-003","added":34,"quantity":34}
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

**Out of stock (`GIZMO-003`, qty 5):** check → `sufficient:"no"`, `shortfall:5` → get history →
reason (e.g. avg order 8 → reorder `5 + 3×8 = 29`; or no history → `5 + 10 = 15`) → restock that
amount → order `delay_days=5` → delivery ≈ today+5. Tell the customer it's delayed.

## Reset (clean slate)

When asked to **reset**, restore the seeded stock and clear all order history in one call:

```bash
curl -s -X POST "$API_BASE/reset"
# => {"reset":true,"inventory":[{"sku":"WIDGET-001","quantity":50}, ...],"orders_cleared":12}
```

Report what came back: stock reseeded and how many orders were cleared. This also wipes the order
history you reason over, so the next short order falls back to the small flat buffer.

## Notes
- Endpoints are public, no auth, no headers needed.
- `/orders` reserves stock atomically — it is the single source of truth for "did it sell".
- The backend never decides the reorder amount — **you** do, from `/history`. That's the AI step.
- Seeded SKUs: `WIDGET-001` (in stock), `GADGET-002` (low: 3), `GIZMO-003` (empty: 0).
