# Sessions API

⚠️ **Sessions live on the `/v1` prefix, NOT `/v3`.** (`/v3/sessions/...` → 405.)
Base: `https://agent-prod.studio.lyzr.ai`. Auth: `x-api-key`. All GET, no body.

`session_id` is whatever you passed to `/v3/inference/chat/`. All endpoints below were
hit live and returned **200**.

| Method | Path | Returns |
|--------|------|---------|
| GET | `/v1/sessions/{session_id}/history` | Array of `{role, content, created_at}` turns |
| GET | `/v1/sessions/{session_id}/{agent_id}/history` | Same, scoped to one agent |
| GET | `/v1/sessions/{session_id}/conversation` | `{"payload": "user: ...\nassistant: ..."}` (flattened transcript) |
| GET | `/v1/sessions/{session_id}/summary` | `{"payload": "{...LLM summary...}"}` |
| GET | `/v1/agent/{agent_id}/sessions` | Array of `{session_id, session_name, ...}` |
| GET | `/v1/agent/{agent_id}/published/sessions` | Array of published sessions |

Optional query param on the `history` endpoints: `unix=true` → epoch timestamps instead of ISO.

Example:
```bash
curl -s "https://agent-prod.studio.lyzr.ai/v1/sessions/$SID/history" -H "x-api-key: $LYZR_API_KEY"
```

Conversation memory: reuse the same `session_id` across chat calls (agents default
`store_messages: true`). History is what these endpoints read back.
