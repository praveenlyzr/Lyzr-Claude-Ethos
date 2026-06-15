# How to run this example — inputs

All three ways (SuperFlow, gitagent, raw curl) drive the **same** live API:

```
API_BASE = https://f50853np0i.execute-api.us-east-1.amazonaws.com
```

Seeded SKUs (reset every `deploy.sh` run):

| SKU          | Stock | What it demonstrates                  |
|--------------|-------|---------------------------------------|
| `WIDGET-001` | 50    | In stock → order ships in **2 days**  |
| `GADGET-002` | 3     | Low stock → in stock up to qty 3      |
| `GIZMO-003`  | 0     | Empty → forces a **restock**, ships in **5 days** |

> Stock is mutable — orders decrement it. Re-run `bash infra/deploy.sh customagents` to reseed
> to the table above.

---

## 1) SuperFlow (`superflow-order-automation.json`)

Import into Lyzr Studio → SuperFlow, then **Run** with this trigger input:

**Scenario A — in stock (no restock):**
```json
{ "sku": "WIDGET-001", "qty": "2", "customer": "acme" }
```
Expected: Route → `sufficient:"yes"` → Place Order (`delay_days=2`) → `201`, delivery ≈ today+2.

**Scenario B — out of stock (restock first):**
```json
{ "sku": "GIZMO-003", "qty": "5", "customer": "acme" }
```
Expected: Route → `sufficient:"no"`, `restock_qty:15` → Restock 15 → Place Order (`delay_days=5`)
→ `201`, delivery ≈ today+5.

> All three trigger fields are strings (they're interpolated straight into the request URLs).

---

## 2) gitagent (`gitagent/`)

Point a gitagent runtime at the `gitagent/` folder and give it a natural-language order. The
agent reads `DUTIES.md` → `skills/order-fulfillment/SKILL.md` and acts with `curl`.

**Scenario A — in stock:**
```
Place an order for customer acme: 2 units of WIDGET-001.
```

**Scenario B — out of stock:**
```
Customer acme wants to order 5 of GIZMO-003.
```

The agent will: check inventory (`?want=`), branch on `sufficient`, restock by `restock_qty` if
needed, place the order with the right `delay_days`, and report the `order_id` + delivery date.
`API_BASE` comes from `agent.yaml`'s `env`.

---

## 3) Raw curl (no SuperFlow / gitagent needed)

```bash
B="https://f50853np0i.execute-api.us-east-1.amazonaws.com"

# --- Scenario A: in stock ---
curl -s "$B/inventory/WIDGET-001?want=2"                                   # sufficient:"yes"
curl -s -X POST "$B/orders?sku=WIDGET-001&qty=2&customer=acme&delay_days=2"

# --- Scenario B: out of stock ---
curl -s "$B/inventory/GIZMO-003?want=5"                                    # sufficient:"no", restock_qty:15
curl -s -X POST "$B/restock?sku=GIZMO-003&qty=15"
curl -s -X POST "$B/orders?sku=GIZMO-003&qty=5&customer=acme&delay_days=5"
```

Every endpoint also accepts a JSON body instead of query params, e.g.:
```bash
curl -s -X POST "$B/orders" -d '{"sku":"WIDGET-001","qty":2,"customer":"acme","delay_days":2}'
```

---

## Field reference

**Inputs**
| Field      | Where            | Example       | Notes |
|------------|------------------|---------------|-------|
| `sku`      | all              | `WIDGET-001`  | must be a seeded SKU (or restock creates it) |
| `qty`      | all              | `5`           | positive integer |
| `customer` | order            | `acme`        | free text, no spaces in the query-param form |
| `want`     | inventory check  | `5`           | quantity you intend to order; triggers the decision fields |
| `delay_days` | order          | `2` or `5`    | days from today to delivery; `2` in-stock, `5` restocked |

**Decision fields returned by `GET /inventory/{sku}?want=N`**
| Field         | Example  | Meaning |
|---------------|----------|---------|
| `sufficient`  | `"yes"`/`"no"` | branch on this |
| `shortfall`   | `5`      | how many short |
| `restock_qty` | `15`     | how much to restock (shortfall + 10 buffer) — pass straight to `/restock` |
