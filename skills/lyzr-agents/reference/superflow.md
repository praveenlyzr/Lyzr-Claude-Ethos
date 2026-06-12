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

## Creating a custom tool from any API → attach in SuperFlow (verified end-to-end)
1. **Create the OpenAPI tool** (host: agent-prod):
   ```bash
   curl -X POST https://agent-prod.studio.lyzr.ai/v3/tools/ -H "x-api-key: $LYZR_API_KEY" -H "Content-Type: application/json" -d '{
     "tool_set_name":"CoinGeckoMarkets",
     "openapi_schema":{"openapi":"3.0.0","info":{"title":"CoinGecko","version":"1.0.0"},
       "servers":[{"url":"https://api.coingecko.com"}],
       "paths":{"/api/v3/coins/markets":{"get":{"operationId":"getCoinMarkets","summary":"Live market data",
         "parameters":[{"name":"vs_currency","in":"query","required":true,"schema":{"type":"string"}},
                       {"name":"ids","in":"query","required":true,"schema":{"type":"string"}}],
         "responses":{"200":{"description":"ok"}}}}}}}'   # -> {"tool_ids":[{"name":"openapi-CoinGeckoMarkets-getCoinMarkets",...}]}
   ```
2. **Get its `provider_uuid`** = the `_id` in `GET /v3/providers/tools/all` for that `provider_id`.
3. **Add a tool node** with `tool_source: "openapi"`, that `provider_uuid`, and `action_names: ["openapi-...-..."]`.
   See `examples/superflow-tool-node-coingecko.json`.

**Runtime-attach also works on plain agents** (verified): put that same `tool_configs` entry on a
`/v3/agents` agent + add a `TOOL_CALLING` feature — the agent then calls the API live. (A bare
`tools: [id]` array does NOT fire — you need `tool_configs`. See [`tools.md`](tools.md).)

## Examples in this skill
- `examples/superflow-tech-pulse-hn.json` — orchestrator + 3 sub-agents + live HACKERNEWS ACI tool (importable).
- `examples/superflow-crypto-risk-swarm.json` — AI Swarm decompose→synthesize risk brief (importable).
- `examples/superflow-tool-node-coingecko.json` — a custom-OpenAPI-tool node to drop into any flow.

## Durability story (for the pitch; doc-derived)
SuperFlow's differentiator is durable, exactly-once execution: steps are journaled, completed steps
never re-run after a crash, approval/wait pauses cost nothing, and cron uses durable timers.
