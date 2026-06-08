# Voice Agents API

⚠️ **Voice agents run on their OWN host:** `https://voice-livekit.studio.lyzr.ai/v1`
(NOT agent-prod). Auth: `x-api-key`. **Create → get → versions → delete verified live**
(create 201, get 200, versions 200, delete 204). Other endpoints doc-derived but consistent.

⚠️ `config.conversation_start.who` must be **`"human"`** or **`"ai"`** (not "agent" → 400).
Create returns `{"agent": {"id", "config", ...}}`; versions carry a UUID `version_id`.

Voice agents are a separate resource type from text agents — different host, different
config schema, LiveKit/WebRTC for realtime audio.

## Verified live
- `GET /agents` → `{"agents": [...]}`
- `GET /config/pipeline-options` → `{stt:[...], tts:[...], llm:[...]}` providers:
  - **STT:** assemblyai, cartesia, deepgram, elevenlabs, sarvam
  - **TTS:** cartesia, deepgram, elevenlabs, inworld, rime, sarvam
  - **LLM:** openai, google, moonshotai, deepseek-ai

## Agent management

| Method | Path | Notes |
|--------|------|-------|
| POST | `/agents` | Create. Body `{ "config": {...} }` (see config below). → `{agent}` |
| GET | `/agents` | List (verified). Query `limit`, `offset` |
| GET | `/agents/{agentId}` | Get details |
| DELETE | `/agents/{agentId}` | Delete (204) |
| POST | `/agents/{agentId}/versions/{versionId}/activate` | Activate a version |
| GET | `/agents/{agentId}/versions` | List versions |
| GET | `/transcripts/agent/{agentId}/stats` | `{totalCalls, browserCalls, phoneCalls, avgMessages}` |
| POST | `/agents/{agentId}/share` | Body `{email_ids:[], admin_user_id}` |
| GET | `/agents/{agentId}/shares` | `{agent_id, user_ids:[]}` |
| POST | `/agents/{agentId}/unshare` | Body `{email_ids:[], admin_user_id}` |

### Create config (`config` object)
```json
{
  "config": {
    "agent_name": "...", "agent_role": "...", "agent_goal": "...",
    "agent_instructions": "...", "prompt": "...",
    "engine": { "kind": "pipeline|realtime", "stt": "deepgram", "llm": "gpt-4o",
                "tts": "elevenlabs", "voice_id": "...", "language": "en" },
    "conversation_start": { "who": "agent|user", "greeting": "Hi, how can I help?" },
    "turn_detection": {}, "noise_cancellation": true, "vad_enabled": true,
    "audio_recording_enabled": true, "knowledge_base": {}, "managed_agents": {},
    "tools": [], "lyzr_tools": [], "background_audio": {},
    "preemptive_generation": true, "pronunciation_rules": {}
  }
}
```
- **Pipeline engine** = STT → LLM → TTS (swap providers individually).
- **Realtime engine** = OpenAI `gpt-4o-realtime`, sub-500ms, better interrupts.

## Pipeline / voice discovery

| Method | Path | Returns |
|--------|------|---------|
| GET | `/config/pipeline-options` | STT/LLM/TTS providers + models ✅ |
| GET | `/config/realtime-options` | Realtime providers + voices (OpenAI `gpt-realtime`) ✅ |
| GET | `/config/tts-voice-providers` | `{providers:[{providerId, configured, supportsSearch}]}` ✅ |
| GET | `/config/tts-voices?providerId=&q=&language=&gender=&limit=&cursor=` | `{providerId, voices:[...], nextCursor}` ✅ |
| GET | `/config/tts-voice-preview?providerId=&url=` | binary `audio/*` |

## Transcripts & tracing

| Method | Path | Returns |
|--------|------|---------|
| GET | `/transcripts` | Query `limit,offset,sort,agentId,sessionId,from,to` → `{items,total,...}` |
| GET | `/transcripts/{sessionId}` | `{transcript:{chatHistory, durationMs, messageCount,...}}` |
| GET | `/transcripts/agent/{agentId}` | Per-agent transcripts |
| GET | `/transcripts/{sessionId}/audio` | `audio/ogg` (needs `audio_recording_enabled`) |
| GET | `/traces/session/{sessionId}` | `{traces:[{traceId, latencySeconds, totalCostUsd,...}]}` |
| GET | `/traces/session/{sessionId}/{traceId}` | Full trace with observations |

## Realtime session (client side)
REST `POST /sessions/start` provisions a LiveKit room + `userToken`; connect with a LiveKit
WebRTC SDK; `POST /sessions/end` to terminate (then transcript/audio become retrievable).
Telephony (SIP) calls are tracked separately as `phoneCalls` in stats.
**Security:** proxy session endpoints through your backend — never expose the API key to the browser.
