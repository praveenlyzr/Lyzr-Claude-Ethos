# temp example: simple order automation

A throwaway example showing the **same workflow built two ways** — a Lyzr **SuperFlow** and a
**gitagent** — both calling real, public, zero-auth AWS endpoints.

## The flow
A customer places an order → check inventory for the SKU → if enough stock, place the order →
if not, call restock to add stock, then place the order → **if a restock happened, push the
delivery date out a few days**.

## Live endpoints (AWS API Gateway + Lambda + DynamoDB, us-east-1, public/no-auth)
Deployed by `infra/deploy.sh` (all resources prefixed `temp-example-simple-order-automation-*`):
- `GET  /inventory/{sku}` → `{ sku, quantity, found }`
- `POST /restock` `{sku, qty}` → `{ sku, added, quantity }`
- `POST /orders` `{sku, qty, customer, delivery_date?}` → `201 {order_id, ...}` or `409` if stock is insufficient
- Seeded SKUs: `WIDGET-001` (50, in stock), `GADGET-002` (3, low), `GIZMO-003` (0, triggers restock)

`POST /orders` atomically reserves stock (never oversells); the **orchestration** (check → restock
→ order → delivery-date) lives in the SuperFlow / gitagent, not the endpoints.

## Contents
- `infra/` — Lambda handlers (`*.mjs`), `seed.json`, `deploy.sh`, `teardown.sh`
- `superflow-order-automation.json` — the SuperFlow build *(added after deploy, with the real API URL)*
- `gitagent/` — the gitagent build *(added after deploy)*

## Deploy / tear down
```bash
aws sso login --profile dev          # (browser)
bash infra/deploy.sh dev             # prints the live API base URL
bash infra/teardown.sh dev           # removes only the temp-example-* resources
```
