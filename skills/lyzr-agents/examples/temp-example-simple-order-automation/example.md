# How to run this example — inputs

> ⚠️ **The endpoints below are torn down** — the `f50853np0i…` URL no longer responds. Re-run
> `bash infra/deploy.sh customagents` to recreate the stack, then replace the base URL throughout
> this file (and in the SuperFlow / gitagent) with the **new** one `deploy.sh` prints.

All three ways (SuperFlow, gitagent, raw curl) drive the **same** API (when deployed):

```
API_BASE = https://f50853np0i.execute-api.us-east-1.amazonaws.com   # example — replaced on each deploy
```

Seeded SKUs (reset every `deploy.sh` run):

| SKU          | Stock | What it demonstrates                  |
|--------------|-------|---------------------------------------|
| `WIDGET-001` | 50    | In stock → order ships in **2 days**  |
| `GADGET-002` | 3     | Low stock → in stock up to qty 3      |
| `GIZMO-003`  | 0     | Empty → forces a **restock**, ships in **5 days** |

> Stock is mutable — orders decrement it and restock adds to it. The **restock branch only fires
> when `qty > current stock`.** So after one out-of-stock run, GIZMO-003 has been restocked and a
> second small order won't be short. To re-trigger the restock path, either order a larger `qty`
> (e.g. `100`) or reset.
>
> **Reset to the canonical state + clear all order history** — just hit the endpoint (no AWS needed):
> ```bash
> curl -s -X POST "https://f50853np0i.execute-api.us-east-1.amazonaws.com/reset"
> # => {"reset":true,"inventory":[…seeded…],"orders_cleared":N}
> ```
> (`bash infra/deploy.sh customagents` also reseeds, but does a full redeploy.)

---

## 1) SuperFlow (`superflow-order-automation.json`)

Nodes: **Trigger → Check Inventory (HTTP) → Route (Switch)** then either
- **yes:** Place Order (HTTP, `delay_days=2`) → Order Placed, or
- **no:** Get History (HTTP) → **Reorder Planner (LLM)** → Restock (HTTP) → Place Order (HTTP, `delay_days=5`) → Order Placed.

The **Reorder Planner is an LLM node** sitting in the middle of the deterministic pipeline — it reads
the order history and decides `restock_qty` (with a `reason`); the Restock step uses that AI number.

Import into Lyzr Studio → SuperFlow, then **Run** with this trigger input:

**Scenario A — in stock (no restock, no AI):**
```json
{ "sku": "WIDGET-001", "qty": "2", "customer": "acme" }
```
Expected: Route → `sufficient:"yes"` → Place Order (`delay_days=2`) → `201`, delivery ≈ today+2.

**Scenario B — out of stock (AI decides the reorder):**
```json
{ "sku": "GIZMO-003", "qty": "5", "customer": "acme" }
```
Expected: Route → `sufficient:"no"` → Get History → **Reorder Planner picks `restock_qty`** →
Restock → Place Order (`delay_days=5`) → `201`, delivery ≈ today+5. With no history the AI will
choose roughly `shortfall + ~10`; after you've placed several orders it reorders deeper.

> All three trigger fields are strings (they're interpolated straight into the request URLs).
> The Reorder Planner uses `gpt-4o-mini` / OpenAI with a strict JSON `responseFormat` — same node
> type as the crypto-copilot example's Classifier.

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

The agent will: check inventory (`?want=`), branch on `sufficient`, and when short **fetch
`/history` and reason about how much to reorder itself** (the gitagent *is* the AI, so the planning
lives in the agent, not the backend), restock by that amount, place the order with the right
`delay_days`, and report the `order_id` + delivery date. `API_BASE` comes from `agent.yaml`'s `env`.

---

## 3) Raw curl (no SuperFlow / gitagent needed)

```bash
B="https://f50853np0i.execute-api.us-east-1.amazonaws.com"

# --- Scenario A: in stock ---
curl -s "$B/inventory/WIDGET-001?want=2"                                   # sufficient:"yes"
curl -s -X POST "$B/orders?sku=WIDGET-001&qty=2&customer=acme&delay_days=2"

# --- Scenario B: out of stock (the SuperFlow/gitagent put an AI step between these calls) ---
curl -s "$B/inventory/GIZMO-003?want=5"                                    # sufficient:"no", shortfall:5
curl -s "$B/history/GIZMO-003"                                             # data the AI reasons over
curl -s -X POST "$B/restock?sku=GIZMO-003&qty=15"                          # qty here is the AI's decision
curl -s -X POST "$B/orders?sku=GIZMO-003&qty=5&customer=acme&delay_days=5"
```

Every endpoint also accepts a JSON body instead of query params, e.g.:
```bash
curl -s -X POST "$B/orders" -d '{"sku":"WIDGET-001","qty":2,"customer":"acme","delay_days":2}'
```

---

## Smart History (AI logic in the middle) — how to see it

The reorder quantity is **not** computed by the backend. When stock is short, the orchestration
fetches `/history/{sku}` and an **AI step decides** how much to reorder:
- In the **SuperFlow**, that's the `Reorder Planner` **LLM node** (output `restock_qty` + `reason`).
- In the **gitagent**, the agent itself reasons over the history.

Its rule of thumb: cover the shortfall plus enough safety stock for expected near-future demand
(≈ `shortfall + 3 × average order size`), falling back to a small flat buffer (~10) when there's
little history. Because it's an LLM, the exact number can vary — read the `reason` it returns.

See the data the AI works with, and how it changes as history grows:
```bash
B="https://f50853np0i.execute-api.us-east-1.amazonaws.com"
curl -s -X POST "$B/reset"                                          # clean slate
curl -s "$B/history/GIZMO-003"                                      # stats.orders:0 -> AI picks a small buffer
curl -s -X POST "$B/restock?sku=GIZMO-003&qty=40" >/dev/null
for i in 1 2 3; do curl -s -X POST "$B/orders?sku=GIZMO-003&qty=8&customer=acme&delay_days=2" >/dev/null; done
curl -s "$B/history/GIZMO-003"                                      # stats.avg_qty:8 -> AI reorders deeper
```

Then run the **out-of-stock SuperFlow scenario** above and watch the `Reorder Planner` node's output
(`restock_qty`, `reason`) drive the Restock step.

---

## Reset (clean slate)

```bash
curl -s -X POST "https://f50853np0i.execute-api.us-east-1.amazonaws.com/reset"
```
Restores stock to the seeded table above and **deletes every order** (clears history). Run it
before a fresh demo, or whenever Smart History / stock has drifted.

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

**Deterministic decision from `GET /inventory/{sku}?want=N`** (backend — routing only)
| Field         | Example  | Meaning |
|---------------|----------|---------|
| `sufficient`  | `"yes"`/`"no"` | branch on this |
| `shortfall`   | `5`      | how many units short (input to the AI reorder step) |

**Order history from `GET /history/{sku}`** (backend — data for the AI to reason over)
| Field   | Example | Meaning |
|---------|---------|---------|
| `stats` | `{orders:3, total_qty:24, avg_qty:8, max_qty:8}` | aggregates over this SKU's past orders |
| `orders`| `[{order_id, qty, customer, created_at}, …]` | the raw orders, newest first |

**Reorder decision (AI — not the backend)** — produced by the SuperFlow `Reorder Planner` LLM node
(or the gitagent), then fed to `POST /restock`:
| Field         | Example | Meaning |
|---------------|---------|---------|
| `restock_qty` | `28`    | units to reorder, chosen by the AI from shortfall + history |
| `reason`      | `"shortfall 4 + ~3× avg order of 8"` | the AI's one-line justification |

---

# Second SuperFlow: insurance product filing (`superflow-insurance-filing.json`)

A separate, self-contained demo in this folder (cleaned-up rewrite of a real flow). It does **not**
use the order API above — its only external calls are echo POSTs to `jsonplaceholder.typicode.com`,
so there's nothing to deploy. Import the JSON into Lyzr Studio → SuperFlow and **Run**.

## The one input: `scenario`

The Trigger takes a single string, `scenario`, which picks a built-in product spec inside
`Product Spec Intake`. Pass one of these:

```json
{ "scenario": "use_and_file" }
```

| `scenario`     | Product the spec builds            | Rule violations? | Route taken & what happens |
|----------------|------------------------------------|------------------|----------------------------|
| `use_and_file` | `iSecure Term Shield` (term, pre-approved) | none | **use_and_file** → Build Launch → Launch Product → Build Regulator Filing → File With IRDAI → **Product Live** |
| `file_and_use` | `WealthMax ULIP Edge` (ULIP, new category, lock-in 5) | none | **file_and_use** → Filing Memo (LLM) → **Actuary Sign-Off (approval pause)** → approve: Build Submission → Submit Filing → **Filed Awaiting Approval** · reject: Rework Notice → **Returned To Product Team** |
| `rework`       | `QuickGain ULIP` (ULIP, lock-in 3, charges not spread) | yes (lock-in < 5; charges not spread) | **rework** → Rework Notice (LLM) → **Returned To Product Team** |

> Routing is computed in `Filing Verdict`: any rule violation → `rework`; else a `pre_approved`
> category → `use_and_file`; else → `file_and_use`. So the scenario indirectly chooses the branch
> by changing the product's `category` / `product_type` / compliance fields.

## Second input: the actuary approval form (only on the `file_and_use` path)

When `scenario` is `file_and_use`, the flow pauses at the **Actuary Sign-Off** (`waitForApproval`)
node and waits for a human to **Approve** or **Reject**, with a small form:

| Form field       | Type   | Required when | Meaning |
|------------------|--------|---------------|---------|
| `actuary_remarks`| string | on **Approve** | appointed actuary's sign-off note (flows into the IRDAI submission) |
| `rework_note`    | string | on **Reject**  | reason the actuary returned it (flows into the rework notice) |

- **Approve** → `actuary_remarks` is attached and the filing is submitted (`Filed Awaiting Approval`).
- **Reject** → `rework_note` is attached and the product is returned (`Returned To Product Team`).

## What to watch

- `use_and_file` exercises the **multi-step external POST chain** (launch → regulator filing, each
  reading the prior response `.body`).
- `file_and_use` exercises the **durable human approval** (the run suspends until you act) and both
  approve/reject outcomes.
- `rework` exercises the **deterministic rule-check → LLM notice** path.

> Demo tip: the merge + branch design is the teaching point — a deterministic `Assess` branch runs
> in parallel with the `Product Summary` LLM, they **merge**, and `Filing Verdict` reads each branch
> by an intrinsic field (no marker flags). See `reference/superflow.md` → Design lessons.
