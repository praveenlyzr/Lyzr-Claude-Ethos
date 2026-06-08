# Agent extras: versions, chat options, events

Base: `https://agent-prod.studio.lyzr.ai`. Auth: `x-api-key`.

## Agent versions (verified)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/v3/agents/{agent_id}/versions` | List versions (**verified 200**). ⚠️ no trailing slash (slash → 405) |
| GET | `/v3/agents/{agent_id}/versions/{version_id}` | Get a specific version → **404 in practice** ⚠️ |

The list returns `{_id, agent_id, created_at, updated_at, versions}` — the version data is
**nested under the `versions` key** of that single record, not a separately-fetchable
resource. Get-specific-version (any id form) returns 404/405, so treat the list response as
the source of truth for version data.

## Chat — full request options (verified core; extras doc-derived)

`POST /v3/inference/chat/` and `POST /v3/inference/stream/` accept:
```json
{
  "user_id": "string (required)",
  "agent_id": "string (required)",
  "session_id": "string (required)",
  "message": "string (required)",
  "system_prompt_variables": {},   // template vars injected into the system prompt (verified accepted)
  "filter_variables": {},          // RAG metadata filters
  "features": []                   // per-request feature toggles
}
```
- Single chat → `{"response": "...", "module_outputs": {}}`.
- Stream → SSE `data:` chunks (concatenate to rebuild the message).
- **Multimodal:** the same chat endpoint accepts referenced asset IDs in the message
  for image/file input (see docs `MultimodalChat`).

## Agent events (live tracing via WebSocket)

After kicking off a chat/stream, subscribe to execution events:
```
wss://metrics.studio.lyzr.ai/session/{session_id}
```
Event payloads include: `feature`, `level`, `status`, `message`, `event_type`,
`run_id`, `trace_id`, `model`, `provider`, `timestamp`.
⚠️ **Headless subscription returns 403** with the `x-api-key` header, no header, or a
query-param key — the metrics WS appears to require browser-origin/Studio auth, and the
`session_id` must be the **server-generated** `{agent_id}-{suffix}` form (not an arbitrary
string). Documented + the endpoint is real, but not reproducible from a plain API-key client.
