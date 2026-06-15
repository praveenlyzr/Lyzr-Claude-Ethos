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

**POST with a JSON body** (`typeVersion: 4`): build the body string in a preceding `code` node and
template it into `jsonBody`.
```json
{ "name": "Submit Filing", "type": "lyzr-nodes-base.httpRequest", "typeVersion": 4,
  "parameters": { "url": "https://api.x.com/posts", "method": "POST",
    "jsonBody": "={{ $json.json_body }}", "sendBody": true, "contentType": "json", "responseFormat": "json" } }
```
Add `settings: { retryOnFail: true, backoff: "exponential" }` for resilience on real endpoints.

### Switch (routing) — `lyzr-nodes-base.switch`
One output branch per rule; wire each branch in `connections.<Switch>.main[i]` (rule 0 → `main[0]`).
```json
{ "name": "Route", "type": "lyzr-nodes-base.switch",
  "parameters": { "rules": { "rules": [
    { "conditions": { "conditions": [ { "leftType": "string", "leftValue": "={{ $json.output.category }}",
        "operation": "equals", "rightType": "string", "rightValue": "support" } ] } }
  ] } } }
```
**`typeVersion: 3`** wraps the operator in an object and allows `combineOperation` (and/or) for
multi-condition rules:
```json
{ "name": "Filing Router", "type": "lyzr-nodes-base.switch", "typeVersion": 3,
  "parameters": { "rules": { "rules": [
    { "conditions": { "conditions": [ { "leftType": "string", "leftValue": "={{ $json.filing_route }}",
        "operator": { "operation": "equals" }, "rightType": "string", "rightValue": "use_and_file" } ],
      "combineOperation": "and" } }
  ] } } }
```

### Code — `lyzr-nodes-base.code`  (`typeVersion: 2`)
```json
{ "name": "Assess", "type": "lyzr-nodes-base.code", "typeVersion": 2,
  "parameters": { "jsCode": "const p = $input.first() || {};\n[Object.assign({}, p, { margin_pct: 12 })]" } }
```
- **An item's json IS the object directly.** `$input.first()` returns the first input object (you
  read `p.product_type`, not `p.json.product_type`); `$input.all()` returns the array of all input
  objects. End the script with a **bare array-of-objects expression** (`[ {...} ]`) — that array is
  the node's output; no `return` needed.
- **Carry the payload forward** with `Object.assign({}, p, { ...new fields })` so downstream nodes
  still have the original fields. Don't emit only your new fields and rely on a later node to
  reassemble — that's what forces the marker-flag anti-pattern (see Design lessons).
- ⚠️ **`lyzr.llm` nodes pass their input THROUGH and add an `output` field.** After an LLM node,
  `$json` has *both* the upstream fields *and* `output: {...}` (the parsed `responseFormat`). So a
  downstream code node can read `p.output.memo` *and* still see `p.product_code`. Use this instead of
  re-threading data around the LLM.

### Merge (join parallel branches) — `lyzr-nodes-base.merge`
```json
{ "name": "Merge Assessments", "type": "lyzr-nodes-base.merge", "parameters": { "mode": "append" } }
```
A merge node has **multiple inputs** — wire each upstream branch to a different input index:
```json
"Assess":          { "main": [[{ "node": "Merge Assessments", "type": "main", "index": 0 }]] },
"Product Summary": { "main": [[{ "node": "Merge Assessments", "type": "main", "index": 1 }]] }
```
`mode: "append"` concatenates the inputs into one item list. Its real value is as a **barrier**: the
merge only fires once *all* its inputs have arrived, so it synchronizes parallel branches before a
downstream node. After it, read each branch by an **intrinsic field** (`items.find(i => i.output)`
for the LLM branch, `items.find(i => i.margin_pct !== undefined)` for the priced branch) — **never**
tag items with marker flags just to find them again (see Design lessons).

### Wait for human approval — `lyzr-nodes-base.waitForApproval`
Durable human-in-the-loop pause. **Two outputs:** `main[0]` = approved, `main[1]` = rejected.
```json
{ "name": "Actuary Sign-Off", "type": "lyzr-nodes-base.waitForApproval", "typeVersion": 1,
  "parameters": {
    "subject": "Actuary sign-off: {{ $('Filing Verdict').json.product_code }}",
    "message": "Product {{ $('Filing Verdict').json.product_name }} needs sign-off. Margin: {{ $('Filing Verdict').json.margin_pct }}%.",
    "formSchema": [
      { "name": "actuary_remarks", "type": "string", "label": "Actuary remarks", "requiredOn": "approve" },
      { "name": "rework_note",     "type": "string", "label": "Rework note",     "requiredOn": "reject" } ] } }
```
The submitted form fields (e.g. `actuary_remarks`) are added to the item passed down the approve/reject
branch. Reference upstream fields in `message`/`subject` via `$('Node').json.<field>` (the immediate
`$json` may just be the prior LLM's `{output, ...}`).

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
the final answer itself. (You can optionally add a plain `lyzr.llm` "Visualizer" node after the
orchestrator to reformat before Output, but it's not required.)

For **plain agents** (not SuperFlow), runtime tool use still needs a `tool_configs` entry +
`TOOL_CALLING` feature — see [`tools.md`](tools.md).

## Example in this skill
`examples/superflow-crypto-copilot.json` — the one canonical SuperFlow demo: an **agentic,
intent-routed crypto copilot**. A Classifier (`lyzr.llm` + `responseFormat` →
`{intent, coin_a, symbol_a, coin_ids}`) feeds a **`switch`** that routes each question down a
different specialist branch:
- **price** → `httpRequest` (CoinGecko markets) → one-line price answer
- **risk** → markets + global + Fear&Greed `httpRequest` fetches → risk brief
- **compare** → one markets call for ALL coins in `coin_ids` → ranked recommendation (safest pick)
- **research** → `taskDecomposition` (AI Swarm) autonomously decomposes + synthesizes

Each branch ends in its own `noOp` Output. It exercises most of the node catalog above: `trigger`
(free-text), `responseFormat`, `switch` (4-way), `httpRequest` (templated URLs + retry/backoff
`settings`), and `taskDecomposition`. Build new flows by composing these same nodes.

`examples/temp-example-simple-order-automation/superflow-insurance-filing.json` — a second demo (an
insurance product-filing flow) that exercises the **merge / waitForApproval / switch-v3 / httpRequest-POST**
nodes and embodies the Design lessons: a deterministic `code` branch runs in parallel with an
`lyzr.llm` summary, they **merge** as a barrier, a `code` "Filing Verdict" disambiguates them by
intrinsic field (no marker flags) and routes via `switch` to launch / file-with-approval / rework —
the file route pausing on a `waitForApproval` actuary sign-off. It's the cleaned-up rewrite of a
real user flow.

## Design lessons (baked into the example)
- **Route multi-option questions to `compare`.** "Which of X/Y/Z is safest / what should I invest
  in" must capture ALL coins (a comma-separated `coin_ids`) and route to compare/recommend — a
  single-item branch silently answers about only one. Make the classifier's `compare` intent
  explicitly include "pick among several / which is safest".
- **Plain-text output.** LLM nodes default to markdown; if you want plain prose, the node's
  `systemPrompt` must explicitly forbid markdown (no `#`, `*`, tables, or bullet symbols) and ask
  for labeled lines.
- **Model for delegation.** `gpt-4o-mini` often under-calls sub-agents in a ReAct orchestrator;
  bump the orchestrator to `gpt-4o` for reliable multi-sub-agent delegation.
- **Data is a pipeline; reasoning is the agent.** SuperFlow agents can't fetch on demand (no working
  agent-owned tools), so put `httpRequest` fetches in the pipeline and let agents reason/route over
  the results.
- **Put the AI judgement *in* the deterministic flow, not in the backend.** A great demo shape is
  `Trigger → httpRequest (fetch facts) → switch (deterministic route) → LLM node (decide) →
  httpRequest (act on the decision)`. Keep the backend "dumb" (serve data + atomic ops, return only
  deterministic fields like `sufficient`/`shortfall`); expose the raw signal (e.g. `GET /history`)
  and let an `lyzr.llm` node with a `responseFormat` json_schema choose the number/branch. Downstream
  HTTP nodes then template the AI's output: `qty={{ $('Reorder Planner').json.output.restock_qty }}`.
  This visibly contrasts AI reasoning against deterministic plumbing — and the same reasoning can be
  done by a gitagent when the orchestrator itself is the AI. (See the order-automation example.)
- **LLM-node prompt can mix literals + multiple expressions.** `prompt` accepts one `=`-expression
  that interpolates several `{{ }}` from different upstream nodes into a sentence, e.g.
  `=SKU {{ $('Trigger').json.sku }} is short by {{ $('Check Inventory').json.body.shortfall }}; history avg {{ $('Get History').json.body.stats.avg_qty }}.`
- **Merge to synchronize, then read by intrinsic field — never tag items with marker flags.** The
  anti-pattern: a code node adds `marker_pricing: true` only so a later node can
  `$input.all().find(i => i.marker_pricing)`. Instead, carry the real payload forward and
  disambiguate merged branches by a field that's *naturally* unique to each (`output` for an LLM
  branch, `margin_pct` for a priced branch). Code nodes should compute real values, not stamp
  identity tags.
- **Only parallelize what's slow.** Splitting two instant synchronous `code` checks into separate
  branches just to `merge` them back adds nodes and a join for no benefit — do them in one node.
  Reserve the parallel-branch + `merge` pattern for a genuinely concurrent cost, e.g. running an
  `lyzr.llm` summary alongside the deterministic checks, then merging the two before the next step.
- **Drive config from the Trigger, not a hardcoded edit line.** A `code` node with
  `const SCENARIO = '...' // EDIT THIS LINE` forces a code change per run. Put the choice in the
  Trigger `inputSchema` and read `$json.scenario` — same flow, no editing.
- **`typeVersion` matters.** Real exports pin it per node (trigger 1, code 2, llm 1, switch 3,
  httpRequest 4). Match the version whose parameter shape you're using — switch v3's
  `operator:{operation}` differs from older flat `operation`.

## Durability story (for the pitch; doc-derived)
SuperFlow's differentiator is durable, exactly-once execution: steps are journaled, completed steps
never re-run after a crash, approval/wait pauses cost nothing, and cron uses durable timers.
