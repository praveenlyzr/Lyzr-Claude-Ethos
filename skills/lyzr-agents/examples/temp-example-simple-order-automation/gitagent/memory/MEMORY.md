# MEMORY

Long-lived facts this agent relies on. Update when the API changes.

- **API base:** `https://f50853np0i.execute-api.us-east-1.amazonaws.com` (public, no auth).
  If redeployed, update this and `agent.yaml`'s `API_BASE`.
- **Backend is dumb; the AI decides the reorder.** `GET /inventory/{sku}?want=N` returns only the
  deterministic decision (`sufficient` `"yes"`/`"no"`, `shortfall`). It does NOT size the reorder.
- **Smart History = your reasoning.** When short, `GET /history/{sku}` → `{stats:{orders,total_qty,
  avg_qty,max_qty}, orders:[…]}`. Choose `restock_qty` ≈ `shortfall + 3 × avg_qty` (flat ~10 if no
  history), then restock by it. In the SuperFlow this is the `Reorder Planner` LLM node.
- **Reset = clean slate.** `POST /reset` reseeds stock to canonical values and deletes every order
  (so the history you reason over resets too). Use it between demos.
- **Delivery promise:** in-stock → `delay_days=2`; restocked → `delay_days=5`.
- **`/orders` is the source of truth for a sale.** It reserves stock atomically; `409` = couldn't
  reserve. Never loop on a `409`.
- **Seeded SKUs:** `WIDGET-001` (in stock), `GADGET-002` (low), `GIZMO-003` (empty → forces restock).
