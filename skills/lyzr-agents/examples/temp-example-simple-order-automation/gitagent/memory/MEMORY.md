# MEMORY

Long-lived facts this agent relies on. Update when the API changes.

- **API base:** `https://f50853np0i.execute-api.us-east-1.amazonaws.com` (public, no auth).
  If redeployed, update this and `agent.yaml`'s `API_BASE`.
- **Decision lives in the inventory check.** `GET /inventory/{sku}?want=N` returns
  `sufficient` (`"yes"`/`"no"`) and `restock_qty` — branch on those; don't recompute.
- **Smart History reorder.** `restock_qty = shortfall + buffer`, where `buffer = max(10, avg_order_qty × 3)`
  computed server-side from the SKU's past orders. Busy SKUs restock deeper; no history → buffer 10.
  The check also returns `history:{orders,total_qty,avg_qty}`. Just use `restock_qty` — never recompute.
- **Reset = clean slate.** `POST /reset` reseeds stock to canonical values and deletes every order
  (so Smart History resets too). Use it between demos.
- **Delivery promise:** in-stock → `delay_days=2`; restocked → `delay_days=5`.
- **`/orders` is the source of truth for a sale.** It reserves stock atomically; `409` = couldn't
  reserve. Never loop on a `409`.
- **Seeded SKUs:** `WIDGET-001` (in stock), `GADGET-002` (low), `GIZMO-003` (empty → forces restock).
