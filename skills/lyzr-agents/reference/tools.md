# Tools API

Base: `https://agent-prod.studio.lyzr.ai`. Auth: `x-api-key`.

**Verified live:** create OpenAPI tool, get-by-id, delete, ready-tool catalog. ⚠️ The
documented **execute** (`/v3/tools/openapi/{id}/execute`) and **toggle** (`PATCH /v3/tools/{id}`)
both return **405** in practice (documented but not functional with this key). And `GET /v3/tools/`
returns `{}` even when a custom tool exists — list it isn't reliable; `GET /v3/tools/{id}` works.

## Runtime attachment — `tool_configs` is the key (now fully verified ✅)

A bare `tools: [id]` array does **not** fire at runtime (even with `TOOL_CALLING`). What works,
**verified live for a custom OpenAPI tool** (an agent called CoinGecko and returned live BTC data):
add a `tool_configs` entry **plus** a `TOOL_CALLING` feature. Confirmed shapes:
```jsonc
// custom OpenAPI tool (tool_source: "openapi")
"tool_configs": [ { "tool_name": "openapi-CoinGeckoMarkets-getCoinMarkets", "tool_source": "openapi",
  "credential_id": "", "provider_uuid": "<_id from /v3/providers/tools/all>",
  "action_names": ["openapi-CoinGeckoMarkets-getCoinMarkets"], "persist_auth": true } ]
// ready/Composio tool (tool_source: "aci")
"tool_configs": [ { "tool_name": "HACKERNEWS", "tool_source": "aci", "credential_id": "",
  "provider_uuid": "6980d823e1440adfe52faf9f", "action_names": ["HACKERNEWS__TOP_STORIES_GET"], "persist_auth": true } ]
```
…plus on the agent: `"features": [ { "type": "TOOL_CALLING", "config": { "max_tries": 3 }, "priority": 0 } ]`.
`provider_uuid` comes from the catalog (`GET /v3/providers/tools/all`); no-auth tools use
`credential_id: ""`. The **same `tool_configs` entry** is what a SuperFlow tool node uses — see
[`superflow.md`](superflow.md).

## How an agent references tools

Agent objects carry two tool fields (seen in live agent JSON):
- `tools` / `tool`: array of tool **id** strings. ⚠️ Storing an id here does NOT activate it
  at runtime (verified — even with a `TOOL_CALLING` feature, the agent didn't see the tool).
- `tool_configs`: array of richer objects — **this is the real activation.** Verified shape
  from a live working agent (ready/`aci` tool):
  ```json
  {
    "tool_name": "LYZR_AGENT",
    "tool_source": "aci",
    "action_names": ["LYZR_AGENT__GET_AGENT"],
    "persist_auth": false,
    "server_id": ""
  }
  ```
  OAuth-backed tools also carry `credential_id` / `provider_uuid`. Pair with a `TOOL_CALLING`
  feature (`{max_tries:3}`). Easiest path: configure tools in Studio, then `GET` the agent to
  copy the exact `tool_configs` it generated.

Also relevant: `tool_usage_description` (string), `a2a_tools`, `mcp_resources`, `mcp_prompts`.

## Tool endpoints

| Method | Path | Purpose | Body / params |
|--------|------|---------|---------------|
| POST | `/v3/tools/` | Create OpenAPI tool ✅ | `tool_set_name`, `openapi_schema` (obj), `default_headers`, `enhance_descriptions`. Returns `{"tool_ids":[{name, description, parameters, method, path}]}` — the tool id is the generated `name` like `openapi-<set>-<operationId>` |
| GET | `/v3/tools/{tool_id}` | Get one tool ✅ | by the generated name |
| DELETE | `/v3/tools/{tool_id}` | Delete tool ✅ | → `{"message":"Tool deleted successfully"}` |
| GET | `/v3/tools/` | List — returns `{}` even when tools exist ⚠️ (unreliable) | — |
| GET | `/v3/providers/tools/all` | Ready-tool (Composio/`aci`) catalog ✅ | array of available tools |
| POST | `/v3/tools/openapi/{tool_id}/execute?path=&method=` | Execute — **405 in practice** ⚠️ | — |
| PATCH | `/v3/tools/{tool_id}?enabled=1` | Toggle — **405 in practice** ⚠️ | — |

## Tool credentials

⚠️ The documented credential endpoints don't behave as written on this deployment:
`POST /v3/tools/credentials` → **405**, `GET /v3/tools/credentials` → **500**. The one that
works is the connected-accounts list:

| Method | Path | Result |
|--------|------|--------|
| GET | `/v3/tools/credentials/connected_accounts?user_id={id}` | ✅ 200 → `[]` (your connected tool accounts) |
| POST | `/v3/tools/credentials` | ⚠️ 405 (documented `name`, `provider_id`, `credentials`, `meta_data` — not functional here) |
| GET | `/v3/tools/credentials` | ⚠️ 500 |

Connecting tool credentials reliably is a Studio flow (OAuth / static-key UI). After connecting
in Studio, reference the resulting `credential_id` in the agent's `tool_configs`.

## Ready-made (Composio) tools

Studio ships pre-built integrations (Gmail, Slack, GitHub, Notion, Google Calendar/Drive,
Outlook, Perplexity, YouTube, Twitter/X, Spotify, ClickUp, Calendly, Discord, Google Tasks).
These are added in Studio and surface on the agent as `tool_configs` entries (with
`tool_source` = the integration and a `credential_id` from an OAuth/credential connect step).
