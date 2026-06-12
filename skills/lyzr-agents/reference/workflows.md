# Workflows / Orchestration API

> ⚠️ **This is NOT SuperFlow.** Two different products: this `/v3/workflows` + `run-dag` engine is
> the **API-driven DAG** (`tasks`/`edges`/`function`, runs headless). **SuperFlow** is the visual
> builder with a totally different n8n-style JSON (`nodes`/`connections`) — see [`superflow.md`](superflow.md).
> Don't paste this engine's JSON into SuperFlow's import (it crashes).

**Storage** is on `https://agent-prod.studio.lyzr.ai`; **execution** is on a separate
orchestration host `https://lao.studio.lyzr.ai`. Auth: `x-api-key`. CRUD verified live.
⚠️ Create returns **`flow_id`** (docs wrongly say `workflow_id`).

| Method | Path | Body / notes | Verified |
|--------|------|--------------|----------|
| POST | `/v3/workflows/` | `flow_name`, `flow_data`, `api_key` → **201** `{flow_id, ...}` (saves; shows in Studio) | ✅ |
| GET | `/v3/workflows/` | List → array of `{flow_id, flow_name, flow_data}` | ✅ |
| GET | `/v3/workflows/{flow_id}` | Get one | ✅ |
| PUT | `/v3/workflows/{flow_id}` | Update (same body as create) → 200 | ✅ |
| POST | `/v3/workflows/{flow_id}/execute` | ⚠️ **STUB** — returns `"result":"Workflow execution placeholder"`, does NOT run the flow. Use run-dag below. | — |
| DELETE | `/v3/workflows/{flow_id}` | Delete → **204** | ✅ |

## Actual execution — the `run-dag` engine ⭐ (verified end-to-end)

Real execution is on `https://lao.studio.lyzr.ai`, async with polling:
```
POST https://lao.studio.lyzr.ai/run-dag/              body = the bare flow_data  -> {"status":"processing","task_id":"..."}
GET  https://lao.studio.lyzr.ai/task-status/{task_id}  -> {"status":"completed","results":{"<node>": <output>, ...}}
```
- **Body is the bare `flow_data`** (`flow_name, run_name, default_inputs, tasks, edges`) at top
  level — NOT wrapped in `workflow_data`/`inputs` (docs are wrong; the wrapper → 422).
- Poll `task-status` until `status` is `completed`/`failed`; `results` is keyed by node name.
- A workflow **must contain ≥1 `call_lyzr_agent`** node, else run-dag → 400.
- Progress WS (browser-origin): `wss://lao-socket.studio.lyzr.ai/ws/{flow_name}/{run_name}`.
- Helper: `scripts/run_workflow.py <flow.json> --inputs '{"user input":"..."}'`.

## Node types & data-flow contract (verified)

Three node `function`s:
| function | params | output |
|----------|--------|--------|
| `api_call` | `config: {url, method, headers}` — **raw external HTTP** (verified live: CoinGecko + Fear&Greed) | parsed JSON response |
| `call_lyzr_agent` | `config: {user_id, session_id, api_key, agent_id, api_url, agent_name}`, `assets: []`, + input/dep mappings | the agent's `response` |
| `gpt_router` | `message`, `fallback_route`, `routes:[{name,description,examples}]`, + a `depends` on the node to classify | `{route, confidence, reasoning, all_scores, user_message}` |

**Data flow is driven by `depends`, NOT edges:**
- A node consumes upstream output via a param `"<upstream>": {"depends": "<upstream>"}`; the engine
  injects each dependency into the agent message as `<node>: <output>` (plus `user input` from
  `default_inputs` when you add `"user input": {"input": "user input"}`).
- **`edges` are ONLY for router branching:** `{"source":"router","target":"<node>","condition":"route == 'X'"}`.
- **Gating gotcha (verified both ways):** a branch node fires conditionally only if it `depends` on the
  **router**. If branches depend on an always-upstream node instead, all of them run.

Full working example: `examples/superflow-crypto-risk-desk.json` (2 live APIs → analyst → router → one of 3 composers).

`flow_data` shape (from live flows):
```json
{
  "tasks": [ { "name": "router_...", "...": "..." } ],
  "edges": [ ... ],
  "default_inputs": { ... },
  "run_name": "..."
}
```
Tasks are nodes (agent calls, routers, conditions); `edges` wire them together. Build
flows visually in the Studio Workflow Builder, then drive them via the execute endpoint.

## Manager agent (multi-agent) — verified end-to-end ✅

A "manager" agent orchestrates other agents at runtime via the `managed_agents` field
on the agent object:
```json
{
  "managed_agents": [
    { "id": "<sub_agent_id>", "name": "Math Agent",
      "usage_description": "Use for any arithmetic/calculation." },
    { "id": "<sub_agent_id>", "name": "Poet Agent",
      "usage_description": "Use to write a short poem about a topic." }
  ]
}
```
Create/chat with it through the normal `/v3/agents/` + `/v3/inference/chat/` endpoints — no
special endpoint needed. **Verified:** a manager with a math sub-agent + a poet sub-agent
correctly routed "144 ÷ 12" → the math agent (answer "12") and "write about the ocean" → the
poet agent (a rhyming couplet). The `usage_description` is what drives routing — make it
specific. See `examples/manager-agent.json`.
