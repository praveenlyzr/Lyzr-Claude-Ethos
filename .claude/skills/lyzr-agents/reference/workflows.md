# Workflows / Orchestration API

Base: `https://agent-prod.studio.lyzr.ai`. Auth: `x-api-key`.
**Full CRUD + execute verified live.** ⚠️ Create returns **`flow_id`** (docs wrongly say
`workflow_id`); that id is what every other endpoint uses.

| Method | Path | Body / notes | Verified |
|--------|------|--------------|----------|
| POST | `/v3/workflows/` | `flow_name`, `flow_data`, `api_key` → **201** `{flow_id, ...}` | ✅ |
| GET | `/v3/workflows/` | List → array of `{flow_id, flow_name, flow_data}` | ✅ |
| GET | `/v3/workflows/{flow_id}` | Get one | ✅ |
| PUT | `/v3/workflows/{flow_id}` | Update (same body as create) → 200 | ✅ |
| POST | `/v3/workflows/{flow_id}/execute` | Run; body `{"input_data": {...}}` → 200 | ✅ |
| DELETE | `/v3/workflows/{flow_id}` | Delete → **204** | ✅ |

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
