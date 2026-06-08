# Channels & cookbooks (recipes)

Doc-derived. Deployment channels and end-to-end build recipes.

## Channels (deploy an agent as a chat bot)
All configured in Studio → Channels. Multi-agent routing uses commands `/agents`, `/list`,
`/switch <name>`, and the channel-agents API:
```bash
POST   /v3/channels/{channel_id}/agents   {"agent_id":"...","name":"..."}
DELETE /v3/channels/{channel_id}/agents/{agent_id}
```
- **Slack** — Slack app with scopes `chat:write, im:read, im:history`; bot OAuth token
  (`xoxb-`), signing secret, bot user id; subscribe to `message.im`.
- **Microsoft Teams** — Azure Bot resource; App ID + password + tenant id; paste webhook URL
  into the bot's Messaging Endpoint (personal DMs only).
- **Telegram** — @BotFather `/newbot` → token (`123456789:ABC...`); enter token, pick agent.

## Cookbooks
- **Data Analyst (text-to-SQL)** — connect DB → semantic model on key tables → schema-doc
  agent generates column descriptions → enable Memory + Data Query → ask in English.
- **Product Support Chatbot** — gpt-4o-mini, temp 0.7; Memory(10) + KB; ingest PDFs/DOCX +
  crawl docs site (set depth/workers/JS-wait); link KB in Core Features.
- **Responsible AI / Compliance bot** — KB of policies (Weaviate + text-embedding-3-large,
  LLMSherpa parser, 7 chunks, MMR, 0.5 threshold) + RAI policy (toxicity 0.3, injection 0.3,
  secrets mask, PII redact names/email/phone/SSN, block credit cards) + Hallucination Manager.
- **Voice Support Agent** — query STT/LLM/TTS config → `POST /agents` (voice config) →
  `/sessions/start` + `/sessions/end` → retrieve transcripts/latency. (see voice-agents.md)
- **Software Manager (multi-agent)** — PRD-guidelines agent → KB → PRD generator → task
  breakdown (structured output) → resource manager → supervisor with Manager toggle + 3 sub-agents.
- **Lyzr MCP on NANDA** — custom MCP server wrapping `/v3/inference/chat/`, SSE at `/sse`, port 8080.
- **Choosing a model** — Fast/affordable (Gemini Flash, Haiku, Sonnet) for support/automation;
  High-intelligence (GPT-5, Opus, Gemini Pro) for research/strategy; Ultra-fast (Groq) for
  voice/realtime. Start balanced (gpt-4o-mini or Sonnet), measure, then tier up/down.
