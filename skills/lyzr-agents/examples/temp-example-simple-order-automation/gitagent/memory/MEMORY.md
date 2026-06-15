# MEMORY

Long-lived facts this agent relies on. Update when the API changes.

- **API base:** `https://f50853np0i.execute-api.us-east-1.amazonaws.com` (public, no auth).
  If redeployed, update this and `agent.yaml`'s `API_BASE`.
- **Decision lives in the inventory check.** `GET /inventory/{sku}?want=N` returns
  `sufficient` (`"yes"`/`"no"`) and `restock_qty` — branch on those; don't recompute.
- **Restock buffer is 10.** `restock_qty = shortfall + 10`, set server-side. Just use the value.
- **Delivery promise:** in-stock → `delay_days=2`; restocked → `delay_days=5`.
- **`/orders` is the source of truth for a sale.** It reserves stock atomically; `409` = couldn't
  reserve. Never loop on a `409`.
- **Seeded SKUs:** `WIDGET-001` (in stock), `GADGET-002` (low), `GIZMO-003` (empty → forces restock).
