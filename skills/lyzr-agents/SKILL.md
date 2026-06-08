---
name: lyzr-agents
description: Build, configure, run, and edit Lyzr AI agents via the Lyzr Agent Studio API (agent-prod.studio.lyzr.ai/v3). Use when the user wants to create, list, inspect, update, delete, or chat with Lyzr agents, set up structured (JSON) output, stream responses, or pick Lyzr LLM providers/models/credentials.
---

# Lyzr Agents

Build and operate agents on the **Lyzr Agent Studio API**. Everything here was verified against the live API.

## Setup

- **Auth header (everything):** `x-api-key: <key>` (NOT a Bearer token)
- **Key location:** `LYZR_API_KEY` in the user's shell env (`~/.zshrc`). Load it with `source ~/.zshrc` before any call, or read it once and pass via env.
- **New users:** see [`SETUP.md`](../../../SETUP.md) (repo root) for getting the key from Lyzr Studio and setting `LYZR_API_KEY` on macOS / Linux / Windows.

### Service hosts (Lyzr is split across several hosts — this trips people up)

| Domain | Host | Prefix |
|--------|------|--------|
| Agents, chat, tools, workflows, agent versions | `https://agent-prod.studio.lyzr.ai` | `/v3` |
| **Sessions** (history/conversation/summary) | `https://agent-prod.studio.lyzr.ai` | **`/v1`** |
| **Knowledge base / RAG** | `https://rag-prod.studio.lyzr.ai` | `/v3` |
| **Responsible AI** (policies + guardrail checks) | `https://rai-prod.studio.lyzr.ai` | `/v1` and root |
| Live event tracing (WebSocket) | `wss://metrics.studio.lyzr.ai` | `/session/{id}` |

Using the wrong host/prefix returns `{"detail":"Method Not Allowed"}` (405) or 404.

### Reference files (per-domain, in `reference/`)

Load the one you need — each marks endpoints **verified** (hit live) vs doc-derived:

Core REST:
- [`reference/agent-extras.md`](reference/agent-extras.md) — agent versions, full chat options, multimodal, WebSocket events
- [`reference/agent-features.md`](reference/agent-features.md) — enabling features (KB, MEMORY, image/PPT/scheduler/webhook…) + top-level fields
- [`reference/sessions.md`](reference/sessions.md) — session history / conversation / summary (`/v1`)
- [`reference/rag.md`](reference/rag.md) — knowledge base / RAG: create, ingest (txt/pdf/docx/website), retrieve, attach (rag-prod)
- [`reference/knowledge-graph-and-database.md`](reference/knowledge-graph-and-database.md) — Neo4j graphs (`/v4`) + DB text-to-SQL (semantic model)
- [`reference/tools.md`](reference/tools.md) — custom OpenAPI tools, credentials, Composio ready-tools
- [`reference/workflows.md`](reference/workflows.md) — workflows + manager (multi-agent) orchestration
- [`reference/responsible-ai.md`](reference/responsible-ai.md) — RAI policies + prompt-injection/toxicity checkers (rai-prod host)
- [`reference/voice-agents.md`](reference/voice-agents.md) — voice agents (voice-livekit host): pipeline/realtime, transcripts, traces
- [`reference/models.md`](reference/models.md) — provider/model/credential catalog

Recipes & SDK / platform / context:
- [`reference/recipes.md`](reference/recipes.md) — **task-oriented playbooks** (support bot, manager, extractor, file-gen, guardrails, scheduler, Cognis, regression check)
- [`reference/lyzr-adk.md`](reference/lyzr-adk.md) — `lyzr-adk` Python SDK (code-first; KB/streaming/Cognis/scheduler verified)
- [`reference/cognis.md`](reference/cognis.md) — Cognis persistent memory layer + Claude-Cognis
- [`reference/superflow.md`](reference/superflow.md) — durable visual workflow engine
- [`reference/platform.md`](reference/platform.md) — build paths, connectors, eval, plans, accounts, MCP server
- [`reference/channels-and-cookbooks.md`](reference/channels-and-cookbooks.md) — Slack/Teams/Telegram + end-to-end recipes
- [`reference/overview-and-glossary.md`](reference/overview-and-glossary.md) — what Lyzr is, concepts, glossary, credits
- [`reference/docs-index.md`](reference/docs-index.md) — **full docs index + fallback instructions** (see below)

### Fallback: when the skill doesn't cover it, read the docs directly

Every Lyzr doc page is available as **raw markdown by appending `.md`** to its URL (no auth).
So nothing in the docs is ever out of reach:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py docs "agent-apis/agents/Create Agent"  # by path
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py docs index                               # the full llms.txt index
# or directly:  curl -s "https://docs.lyzr.ai/<path>.md"   /   WebFetch the same URL
```
`reference/docs-index.md` is a bundled snapshot of the full index (title → URL → description)
to grep for the right page first. Always prefer **live-verifying** a doc-derived endpoint
against the API before promising it works.

Quick check that auth works:
```bash
source ~/.zshrc
curl -s "https://agent-prod.studio.lyzr.ai/v3/agents/" -H "x-api-key: $LYZR_API_KEY" | python3 -m json.tool | head
```

> **Script paths:** examples use `${CLAUDE_PLUGIN_ROOT}` — Claude Code sets this to the
> plugin's install directory, so the commands work wherever the plugin is installed. If you're
> running from a clone of the repo instead, substitute the repo root for `${CLAUDE_PLUGIN_ROOT}`
> (e.g. `python3 skills/lyzr-agents/scripts/lyzr.py …`).

## Helper CLI (preferred)

`scripts/lyzr.py` wraps every verified operation. Prefer it over raw curl for anything multi-field.

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py list
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py get <agent_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py create --file agent.json
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py update <agent_id> --file agent.json
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py delete <agent_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py chat <agent_id> "your message" [--session S] [--stream]
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py models   # known provider/model/cred combos

# read-side helpers (all verified live)
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py versions <agent_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py sessions <agent_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py history <session_id> [--agent <agent_id>]
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-list [--user <id>]
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-get <rag_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-retrieve <rag_id> "query" [--top-k N] [--type basic|mmr|hyde|time_aware]
# RAG write side (verified end-to-end):
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-create <collection_name> [--user <id>]
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-train <rag_id> <file> [--kind txt|pdf|docx]
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-reset <rag_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rag-delete <rag_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py workflows
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py workflow-get <flow_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py workflow-delete <flow_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py ready-tools             # Composio/aci tool catalog
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py tool-delete <tool_id>
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py voice-list              # voice agents
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rai-policies            # list RAI policies
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rai-injection "text"   # prompt-injection check
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py rai-toxicity  "text"   # toxicity check
python3 ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py docs "<path|url|index>"  # fallback: fetch any doc page
```
The script targets the right host automatically (agent-prod / rag-prod / rai-prod / voice).

Other scripts:
- `scripts/recipe_support_bot.sh <kb_name> <doc> [agent_name]` — one-command KB+memory support bot (verified)
- `scripts/rag_smoke_test.sh` — 17-check end-to-end RAG test (self-cleaning)
- `scripts/surface_check.sh` — full-surface drift detector: re-verifies every endpoint across all hosts (run after Lyzr API updates)

## Endpoints (all verified)

| Method | Path | Purpose | Returns |
|--------|------|---------|---------|
| GET | `/v3/agents/` | List all agents for the API key | JSON array of full agent objects |
| POST | `/v3/agents/` | Create an agent | `{"agent_id": "<id>"}` |
| GET | `/v3/agents/{id}` | Get one agent (⚠️ **no** trailing slash — trailing slash → 405) | Full agent object |
| PUT | `/v3/agents/{id}` | Update an agent (send the **full** body) | `{"message": "Agent updated successfully"}` |
| DELETE | `/v3/agents/{id}` | Delete an agent | `{"message": "Agent deleted successfully"}` |
| POST | `/v3/inference/chat/` | Chat (single response) | `{"response": "...", "module_outputs": {}}` |
| POST | `/v3/inference/stream/` | Chat (SSE stream) | `data: <chunk>` SSE events |

Notes:
- Unknown/wrong-method routes return `{"detail":"Method Not Allowed"}` with HTTP 405.
- There is no working `models`/`providers` GET endpoint (all return 405) — use the known list below.

## Creating an agent

Minimal verified create body (`POST /v3/agents/`):

```json
{
  "name": "My Agent",
  "description": "What it does.",
  "agent_role": "Who the agent is.",
  "agent_instructions": "Step-by-step instructions for the agent.",
  "agent_goal": "What it should achieve.",
  "features": [],
  "tools": [],
  "llm_credential_id": "lyzr_anthropic",
  "provider_id": "Anthropic",
  "model": "claude-sonnet-4-6",
  "top_p": 0.95,
  "temperature": 0.5
}
```

Full set of agent fields (from a live agent object): `name`, `description`, `agent_role`,
`agent_instructions`, `agent_goal`, `agent_context`, `agent_output`, `examples`,
`features` (array), `tool`/`tools`, `tool_usage_description`, `response_format`,
`provider_id`, `model`, `top_p`, `temperature`, `managed_agents`, `tool_configs`,
`store_messages` (default true), `file_output` (default false), `disable_artifacts`,
`a2a_tools`, `voice_config`, `additional_model_params`, `image_output_config`,
`max_iterations` (default 25), `llm_credential_id`, `version` ("3"), `template_type`
(e.g. `single_task`).

**Updating:** `PUT /v3/agents/{id}` replaces config — send the complete body, not a patch.
Easiest flow: `get` the agent, edit the JSON, `update` with the edited object.

## Provider / model / credential combos (verified in use)

`llm_credential_id` uses Lyzr-managed shared credentials so you don't need your own keys:

| provider_id | model | llm_credential_id |
|-------------|-------|-------------------|
| `Anthropic` | `claude-sonnet-4-6` | `lyzr_anthropic` |
| `OpenAI` | `gpt-4.1`, `gpt-4o`, `gpt-4o-mini`, `gpt-5`, `o3` | `lyzr_openai` |
| `OpenAI` | `gpt-5-nano` | `lyzr-default` |
| `Google` | `gemini-2.0-flash`, `gemini/gemini-3.1-flash-lite` | `lyzr_google` |

Default recommendation: `Anthropic` / `claude-sonnet-4-6` / `lyzr_anthropic`.

## Chatting with an agent

`POST /v3/inference/chat/`:
```json
{
  "user_id": "praveen@lyzr.ai",
  "agent_id": "<agent_id>",
  "session_id": "any-string-you-choose",
  "message": "the user's message"
}
```
- `session_id` is free-form; reuse the same value to keep conversation memory (agent has `store_messages: true`).
- Response: `{"response": "<text>", "module_outputs": {}}`.
- Streaming: same body to `/v3/inference/stream/`, returns SSE `data:` chunks.

## Structured (JSON) output

Set `response_format` to a JSON-schema spec on the agent. Verified shape:
```json
{
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "MyResponse",
      "strict": true,
      "schema": {
        "type": "object",
        "properties": {
          "field_a": {"type": "string", "description": "..."},
          "field_b": {"type": "string", "description": "..."}
        },
        "required": ["field_a", "field_b"],
        "additionalProperties": false
      }
    }
  }
}
```
The agent's `response` will then be a JSON **string** matching the schema (parse it client-side).
Reinforce the schema in `agent_instructions` too for best reliability.

## Knowledge base (RAG) agent — quickstart

Verified end-to-end (`reference/rag.md` has full detail; `scripts/rag_smoke_test.sh` is a
17-check living test of this exact flow):

```bash
S=${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/lyzr.py
RID=$(python3 $S rag-create my_kb | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
python3 $S rag-train "$RID" ./docs.txt          # or --kind pdf|docx
# then create an agent with a KNOWLEDGE_BASE feature pointing at $RID
# (see examples/knowledge-base-agent.json — replace rag_id + rag_name) and chat normally.
```
The agent retrieves from the KB automatically at chat time. Confirmed it answers
KB-only facts, pulls across multiple ingested docs, and says "I don't know" for facts
absent from the KB (no hallucination). Run the smoke test anytime to re-verify:
```bash
LYZR_USER_ID="you@example.com" bash ${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/rag_smoke_test.sh
```

## Gotchas

- Auth is `x-api-key`, not `Authorization: Bearer`.
- GET-by-id: no trailing slash. List/create: trailing slash (`/v3/agents/`).
- Create returns `agent_id`; update/delete return a `message`.
- PUT is a full replace — fetch-edit-put.
- `tools`/`features` accept `[]` when unused; omit-or-empty is fine.
