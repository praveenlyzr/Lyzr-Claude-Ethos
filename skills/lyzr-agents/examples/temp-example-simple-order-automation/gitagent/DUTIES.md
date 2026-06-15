# DUTIES

## Duty 1 — fulfill an order (given `sku`, `qty`, `customer`)

Run the [order-fulfillment skill](skills/order-fulfillment/SKILL.md). In short:

1. **Check inventory** — `GET $API_BASE/inventory/{sku}?want={qty}`.
2. **Decide** on the response's `sufficient` field:
   - `"yes"` → go straight to step 4 with `delay_days=2`.
   - `"no"`  → **reason + restock first** (step 3), then step 4 with `delay_days=5`.
3. **Reorder reasoning + restock** (the AI step). `GET $API_BASE/history/{sku}`, then **decide**
   `restock_qty` from the shortfall + order history (cover the shortfall plus ~3× the average order
   size; small flat buffer if no history). Then `POST $API_BASE/restock?sku={sku}&qty={restock_qty}`.
4. **Place the order** — `POST $API_BASE/orders?sku={sku}&qty={qty}&customer={customer}&delay_days={2 or 5}`.
   Expect `201` with an `order_id` and `delivery_date`. A `409` means the order could not be
   reserved — stop and report it.
5. **Report** the outcome to the user (order id, qty, restocked yes/no + reasoning, delivery date).

> The backend does NOT compute the reorder amount — **you** do, from `/history` (Smart History).
> That's the deliberate AI-in-the-middle step; cite the numbers you reasoned from.

## Duty 2 — reset on request

If the user asks to **reset** (clean slate), call `POST $API_BASE/reset`. This reseeds stock to the
canonical values and clears all order history. Report stock reseeded + how many orders were cleared.
See the skill's "Reset" section.
