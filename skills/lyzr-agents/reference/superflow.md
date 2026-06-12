# SuperFlow — visual workflows (the real, importable schema)

⚠️ **SuperFlow is a DISTINCT product from the `/v3/workflows` orchestration engine**
([`workflows.md`](workflows.md)). They are NOT the same and their JSON is NOT interchangeable:
- **`/v3/workflows` + `run-dag`** = the API-driven DAG (`tasks`/`edges`/`function`, executed headless).
- **SuperFlow** = the visual builder, an **n8n-style** graph (`nodes` + `connections`). This is what
  the Studio UI's **Import JSON** expects. Pasting `/v3/workflows` JSON into SuperFlow **crashes it.**

Schema below is **verified** against real Studio exports + a live tool-execution test. There is no
public SuperFlow execution API found — build/import/run it in the Studio UI (export JSON to capture
the exact shape; the `.md` docs for SuperFlow are currently 404).

## Top-level shape
```json
{
  "name": "My Flow",
  "nodes": [ { "id": "...", "name": "...", "type": "lyzr-nodes-base.*", "parameters": {...}, "position": [x, y] } ],
  "connections": {
    "<SourceNodeName>": { "main": [[ { "node": "<TargetNodeName>", "type": "main", "index": 0 }, ... ]] }
  }
}
```
- `connections` is keyed by node **name** (not id); `main[0]` is an array of downstream targets.
- Every node needs a unique `id`, a `name`, a `type`, `parameters`, and a `[x,y]` `position`.

## Node types (`type` strings — all verified from real exports)

### Trigger — `lyzr-nodes-base.trigger`
```json
{ "id": "node_0", "name": "Trigger", "type": "lyzr-nodes-base.trigger",
  "parameters": { "inputSchema": [ { "name": "chatInput", "type": "string", "required": true, "multiline": true, "description": "..." } ] },
  "position": [200, 200] }
```
Downstream nodes read the input via the n8n expression `={{ $json.chatInput }}`.

### LLM (agent / orchestrator) — `lyzr-nodes-base.lyzr.llm`
Orchestrator (top-level reasoner; omit `isSubAgent`):
```json
{ "name": "Orchestrator", "type": "lyzr-nodes-base.lyzr.llm",
  "parameters": { "model": "gpt-4o-mini", "provider": "openai", "prompt": "={{ $json.chatInput }}",
                  "maxTokens": 2048, "temperature": 0.4, "systemPrompt": "...how to use the tools/sub-agents..." } }
```
Sub-agent (callable BY the orchestrator — add `isSubAgent: true` + a `description` the orchestrator sees):
```json
{ "name": "Researcher", "type": "lyzr-nodes-base.lyzr.llm",
  "parameters": { "model": "gpt-4o-mini", "provider": "openai", "maxTokens": 2048, "temperature": 0.2,
                  "isSubAgent": true, "description": "Look up facts; return 2-3 sentences.", "systemPrompt": "..." } }
```
**Structured output** — add `responseFormat` (json_schema) to any `lyzr.llm` node; the parsed result
is then readable downstream as `={{ $json.output.<field> }}`:
```json
"responseFormat": { "type": "json_schema", "json_schema": { "name": "coin", "strict": true,
  "schema": { "type": "object", "required": ["coin_id"],
    "properties": { "coin_id": { "type": "string" } }, "additionalProperties": false } } }
```

### HTTP Request — `lyzr-nodes-base.httpRequest`  ⭐ the right way to call external APIs
```json
{ "name": "Fetch Page", "type": "lyzr-nodes-base.httpRequest",
  "parameters": { "url": "={{ $json.url }}", "method": "GET", "sendHeaders": false } }
```
The response lands in **`.body`** — read it downstream with `={{ $json.body }}` or
`={{ $('Fetch Page').json.body }}`. The `url` can be templated:
`"url": "=https://api.x.com/q?id={{ $('Extract').json.output.coin_id }}"`. **Prefer this over
custom OpenAPI `lyzr.tool` nodes for fetching data** — no `provider_uuid`, no tool registration,
no missing-required-param 4xx, no zero-param 404. (The `lyzr.tool`/`isSubAgent` path is for the
ReAct "agent decides which tool to call" pattern, not deterministic data fetches.)

### Switch (routing) — `lyzr-nodes-base.switch`
One output branch per rule; wire each branch in `connections.<Switch>.main[i]`.
```json
{ "name": "Route", "type": "lyzr-nodes-base.switch",
  "parameters": { "rules": { "rules": [
    { "conditions": { "conditions": [ { "leftType": "string", "leftValue": "={{ $json.output.category }}",
        "operation": "equals", "rightType": "string", "rightValue": "support" } ] } }
  ] } } }
```

### Code — `lyzr-nodes-base.code`
```json
{ "name": "Split Lines", "type": "lyzr-nodes-base.code",
  "parameters": { "jsCode": "$json.texts.split('\\n').filter(Boolean).map(text => ({ json: { text } }));" } }
```

### Loop — `lyzr-nodes-base.splitInBatches`
`{ "mode": "each", "batchSize": 1 }`. Two outputs: `main[0]` = loop body, `main[1]` = done.

### AI Swarm (decompose → solve → aggregate) — `lyzr-nodes-base.lyzr.taskDecomposition`
```json
{ "name": "AI Swarm", "type": "lyzr-nodes-base.lyzr.taskDecomposition",
  "parameters": { "model": "gpt-4o-mini", "provider": "openai", "prompt": "={{ $json.chatInput }}",
                  "maxTokens": 2048, "maxSubtasks": 5, "temperature": 0.4,
                  "decompositionPrompt": "Break the topic into 3-5 subtasks...", "aggregationPrompt": "Synthesize the answers..." } }
```

### Tool (ACI or custom OpenAPI) — `lyzr-nodes-base.lyzr.tool`
```json
{ "name": "Hacker News", "type": "lyzr-nodes-base.lyzr.tool",
  "parameters": {
    "tool_name": "HACKERNEWS__TOP_STORIES_GET",
    "tool_configs": [ { "tool_name": "HACKERNEWS", "tool_source": "aci", "credential_id": "",
        "provider_uuid": "6980d823e1440adfe52faf9f", "action_names": ["HACKERNEWS__TOP_STORIES_GET"], "persist_auth": true } ],
    "arguments": {}, "_selectedTool": "6980d823e1440adfe52faf9f", "_isConnected": false, "_noAuthRequired": true,
    "action_schema": { "type": "object", "visible": [], "required": [], "properties": {}, "additionalProperties": false } } }
```
- `provider_uuid` = the tool's `_id` from `GET /v3/providers/tools/all`.
- `tool_source`: **`aci`** for catalog/Composio tools, **`openapi`** for custom OpenAPI tools (see recipe below).
- No-auth tools: `credential_id: ""`, `_noAuthRequired: true`. OAuth tools: connect once in Studio, then set `credential_id`.
- `action_schema` mirrors the action's input params (see the CoinGecko example).

⚠️ **`arguments` must contain every REQUIRED param, or the call fails (verified).** The tool
executor sends ONLY what's in `arguments` — it does **not** apply OpenAPI schema defaults or a
query string baked into the path. So a node with `"arguments": {}` whose API has a required
param 4xx's (e.g. CoinGecko `/coins/markets` → 422 "Missing parameter vs_currency", surfaced as
a 400). HACKERNEWS works with empty `arguments` only because it has no required params.
Fix: populate them, e.g. `"arguments": { "vs_currency": "usd", "ids": "bitcoin,ethereum,solana" }`.
Prefer tools whose required inputs you can pin here; keep dynamic-but-optional inputs out of `required`.
(Also: never set `isSubAgent`/`description` on a tool node — those belong on `lyzr.llm` sub-agents.)

⚠️ **A tool whose action schema has ZERO parameters fails to register in SuperFlow** —
runtime error `platform returned status 404: Tool '...' not found in any provider`, even though
the tool exists in `GET /v3/providers/tools/all` and works fine when attached to a plain agent.
(Observed: a no-param CoinGecko `/global` OpenAPI tool 404'd in SuperFlow; the parameterized
Markets tool resolved.) Fix: give every OpenAPI tool **at least one parameter** in its schema —
even a single optional, unused one (`"properties": { "_": { "type": "string" } }`) is enough,
since CoinGecko-style APIs ignore unknown query params. Recreate the tool (new `provider_uuid`)
with a non-empty schema and point the node at it.

### Per-node reliability `settings` (verified from real exports)
Any node can carry a sibling `settings` block (next to `parameters`) for durable retry/backoff:
```json
{ "type": "lyzr-nodes-base.lyzr.tool", "parameters": { ... },
  "settings": { "retryOnFail": true, "backoff": "exponential" },   // backoff: "exponential" | "fixed"
  "position": [x, y] }
```
A tool node can also set `"handleErrors": true` inside `parameters` to keep the flow running if the
call fails. **Use retry/backoff on rate-limited APIs** — the free CoinGecko endpoints 429 under load,
so `retryOnFail: true, backoff: "exponential"` materially helps the demo.

⚠️ **Selecting a tool in the UI is not the same as configuring it.** A node can end up with
`"_selectedTool": "<uuid>"` but `"tool_name": ""` and `"tool_configs": []` — that tool will NOT
resolve at runtime. Always populate `tool_name` + a full `tool_configs[]` entry (matching the
`_selectedTool` uuid). See the CoinGecko nodes in the example.

### Output — `lyzr-nodes-base.noOp`
```json
{ "name": "Output", "type": "lyzr-nodes-base.noOp", "parameters": { "outputField": "output", "outputSourceNode": "Orchestrator" } }
```

## Multi-agent orchestration pattern (verified)
The orchestrator LLM "has" its sub-agents and tools by being **connected to them**. Wire the
orchestrator's `connections.main[0]` to every sub-agent, tool, AND the Output:
```json
"connections": {
  "Trigger": { "main": [[{ "node": "Orchestrator", "type": "main", "index": 0 }]] },
  "Orchestrator": { "main": [[
    { "node": "Hacker News", "type": "main", "index": 0 },
    { "node": "Trend Analyst", "type": "main", "index": 0 },
    { "node": "Output", "type": "main", "index": 0 } ]] }
}
```
The orchestrator's `systemPrompt` tells it when to call each tool/sub-agent.

## External APIs: use `httpRequest`, not custom `lyzr.tool` (lesson learned the hard way)
Earlier this skill tried to call CoinGecko via custom OpenAPI `lyzr.tool` nodes. That path is
fragile in SuperFlow: required params 4xx unless pinned in `arguments`, zero-param tools 404 on
registration, and the UI can leave `tool_name`/`tool_configs` empty. **The official examples all
use `httpRequest`** for fetching data — just template the URL and read `.body`. Use `lyzr.tool` only
for the ACI/Composio catalog (Gmail, Slack, etc.) or the ReAct agent-as-tool pattern.

⚠️ **A sub-agent cannot own/call a custom tool or API in SuperFlow (user-confirmed).** Wiring a
`lyzr.tool` (e.g. custom CoinGecko OpenAPI) to an `isSubAgent` LLM and expecting the sub-agent to
fetch on demand does **not** work. And `httpRequest` is a *pipeline* node — an agent can't invoke it
mid-reasoning. So the "main agent delegates to a specialist that goes and fetches" pattern isn't
achievable; instead use a **data layer + reasoning layer**: (1) a **data layer** of `httpRequest`
nodes fetches everything up front, (2) a **reasoning layer** — a ReAct orchestrator that delegates
to `isSubAgent` specialists which *reason over* the fetched data (and debate, multi-step), then writes
the final brief itself. See `examples/superflow-crypto-risk-desk.json` (Extract → 4 httpRequest →
Strategist ⇄ Price/Context agents → Output). (You can optionally add a plain `lyzr.llm` "Visualizer"
node after the orchestrator to reformat the output before Output, but it's not required.)

For **plain agents** (not SuperFlow), runtime tool use still needs a `tool_configs` entry +
`TOOL_CALLING` feature — see [`tools.md`](tools.md).

## Example in this skill
- `examples/superflow-crypto-risk-desk.json` — the full, importable demo on the official
  `httpRequest` pattern. **13 nodes:** Trigger → Extract Coin (`lyzr.llm` + `responseFormat`) →
  **5 live `httpRequest` fetches** (CoinGecko markets + Coinbase spot + global + Fear&Greed +
  7-day history, retry/backoff each) → **Compute Volatility (`code` node)** → **Risk Strategist**
  that delegates to 3 `isSubAgent` specialists (Price Agent reconciles the two price feeds, Context
  Agent reads regime, Red Team argues the contrarian case) → Output. Dynamic per coin; showcases
  httpRequest + code + responseFormat + multi-sub-agent ReAct in one flow.
- `examples/superflow-official/` — the 7 official Lyzr SuperFlow examples (Ask the AI, Code Reviewer,
  Web Page Summarizer [httpRequest], Batch Sentiment [code+loop+responseFormat], Smart Email Triage
  [switch], Research Swarm [taskDecomposition], ReAct Agent [orchestrator+sub-agents]) — the
  authoritative schema reference. Start from these when building new flows.

## Durability story (for the pitch; doc-derived)
SuperFlow's differentiator is durable, exactly-once execution: steps are journaled, completed steps
never re-run after a crash, approval/wait pauses cost nothing, and cron uses durable timers.
