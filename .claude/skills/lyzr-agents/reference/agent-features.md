# Agent features & top-level options

How to turn on capabilities when creating/updating an agent. Two mechanisms:

1. **Top-level agent fields** (verified from real agent JSON).
2. **`features[]` entries** — each is `{ "type": "<TYPE>", "config": { ... }, "priority": <int> }`.

The `features[]` types below were **enumerated from the live API** (every distinct `type`
across all real agents on this account) — so these are the actual type strings and config
shapes, not doc guesses.

## Top-level fields (verified)
| Field | Meaning |
|-------|---------|
| `response_format` | Structured JSON output (json_schema) — see SKILL.md "Structured output" |
| `max_iterations` | Max tool/agent/generation steps per request (default 25) |
| `store_messages` | Persist conversation for session memory (default true) |
| `file_output` | Allow file artifacts (default false) |
| `managed_agents` | Multi-agent manager (see workflows.md) |
| `tool` / `tools` / `tool_configs` | Tools (see tools.md) |
| `provider_id`, `model`, `llm_credential_id`, `temperature`, `top_p` | LLM config |

## features[] entries — REAL types (enumerated live)

```json
{ "type": "MEMORY", "priority": 0,
  "config": { "provider": "cognis",
              "lyzr_memory": { "provider_type": "cognis", "params": { "cross_session": false } } } }
```
```json
{ "type": "SHORT_TERM_MEMORY", "config": {}, "priority": 0 }
```
```json
{ "type": "KNOWLEDGE_BASE", "priority": 0,
  "config": { "lyzr_rag": { "base_url": "https://rag-prod.studio.lyzr.ai",
      "rag_id": "<id>", "rag_name": "<collection>",
      "params": { "top_k": 10, "retrieval_type": "basic", "score_threshold": 0 } },
    "agentic_rag": [] } }
```
```json
{ "type": "TOOL_CALLING", "config": { "max_tries": 3 }, "priority": 0 }
```
```json
{ "type": "SINGLE_TOOL_CALL", "config": { "module_mode": "Pre" }, "priority": 0 }
```
```json
{ "type": "VOICE", "priority": 0,
  "config": { "voice_id": "21m00Tcm4TlvDq8ikWAM",
              "elevenlabs_key": "<cred_id>", "deepgram_key": "<cred_id>" } }
```

> A simpler MEMORY form `{"config":{"max_messages_context_count":50}}` is also accepted —
> both work. Multiple features can coexist (e.g. MEMORY + KNOWLEDGE_BASE + TOOL_CALLING).

## File output (artifacts) — VERIFIED ✅
Top-level `"file_output": true`. Ask the agent to produce a document; the chat response carries:
```json
"module_outputs": { "artifact_files": [
  { "file_url": "https://url-shortner.studio.lyzr.ai/...", "artifact_id": "...",
    "name": "Quarterly Summary Report", "format_type": "pdf" } ] }
```
Verified: generated and downloaded a real PDF (`format_type` also docx/pptx). GET the `file_url` to download.

## Image output — config accepted, generation gated
`"image_output_config": { "enabled": true, "provider": "openai", "model": "dall-e-3",
"credential_id": "<id>" }` (top-level; `credential_id` is **required**). The config is
accepted, but generation with the shared `lyzr_openai` credential **errors** (`module_outputs:
{}`) — needs a dedicated image-gen credential.

## Scheduler — VERIFIED via SDK ✅
`studio.create_schedule(user_id, agent_id, cron_expression, message="", timezone="UTC",
max_retries=3, retry_delay=60)` → Schedule with `id`; `list_schedules()` / `delete_schedule(id)`
verified. (REST scheduler paths weren't found — use the SDK.) PPT/webhook/global-context have
no confirmed REST `features[]` shape; use the SDK (`file_output`, `create_context`, …).
Structured output: prefer the verified top-level `response_format`.

## Responsible AI
RAI guardrails are created as a policy (see responsible-ai.md). The exact agent field that
binds a policy to an agent isn't exposed on existing agents' JSON — set it in Studio, or use
the SDK `rai_policy=` / `agent.add_rai_policy(...)`.
