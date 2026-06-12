# Lyzr-Claude-Ethos

A Claude Code **plugin** (and one-plugin **marketplace**) that ships the `lyzr-agents` skill
for building, running, and editing [Lyzr](https://lyzr.ai) AI agents via the Lyzr Agent Studio API.

## Install

```bash
# in Claude Code:
/plugin marketplace add praveenlyzr/Lyzr-Claude-Ethos
/plugin install lyzr-agents@lyzr
```
Then set your key (see [SETUP.md](SETUP.md)) and the skill activates automatically when you
ask Claude to work with Lyzr agents. To try it from a local clone instead:
`/plugin marketplace add ./Lyzr-Claude-Ethos`.

## What's here

```
.claude-plugin/
├── marketplace.json                  # marketplace manifest (name: "lyzr")
└── plugin.json                       # plugin manifest (name: "lyzr-agents")
skills/lyzr-agents/
├── SKILL.md                          # The skill: verified API reference + multi-host map
├── scripts/
│   ├── lyzr.py                       # CLI: agents CRUD, chat, sessions, versions, rag, workflows, RAI, docs
│   ├── recipe_support_bot.sh         # one command → KB + memory support bot (verified)
│   ├── rag_smoke_test.sh             # 17-check end-to-end RAG test (create→ingest→agent→chat→cleanup)
│   └── surface_check.sh              # full-surface drift detector across all hosts
├── examples/
│   ├── basic-agent.json              # Minimal agent template
│   ├── structured-output-agent.json  # Agent with strict JSON response_format
│   ├── knowledge-base-agent.json     # Agent wired to a RAG knowledge base
│   ├── manager-agent.json            # Manager that delegates to sub-agents
│   └── superflow-crypto-risk-desk.json  # SuperFlow: orchestrator + 3 live tools + 2 sub-agents (importable)
└── reference/                        # Per-domain API references (verified vs doc-derived)
    ├── agent-extras.md               # versions, chat options, multimodal, WebSocket events
    ├── agent-features.md             # enabling features + top-level agent fields
    ├── sessions.md                   # session history/conversation/summary (/v1 host)
    ├── rag.md                        # KB/RAG: create, ingest txt/pdf/docx/website, retrieve, attach
    ├── knowledge-graph-and-database.md  # Neo4j graphs (/v4) + DB text-to-SQL (semantic model)
    ├── tools.md                      # OpenAPI tools, credentials, Composio ready-tools
    ├── workflows.md                  # workflows + manager (multi-agent) orchestration
    ├── responsible-ai.md             # RAI policies + injection/toxicity checks (rai-prod host)
    ├── voice-agents.md               # voice agents (voice-livekit host)
    ├── models.md                     # provider/model/credential catalog
    ├── lyzr-adk.md                   # lyzr-adk Python SDK
    ├── cognis.md                     # Cognis persistent memory + Claude-Cognis
    ├── superflow.md                  # durable visual workflow engine
    ├── platform.md                   # build paths, connectors, eval, plans, accounts, MCP server
    ├── channels-and-cookbooks.md     # Slack/Teams/Telegram + end-to-end recipes
    ├── overview-and-glossary.md      # what Lyzr is, concepts, glossary, credits
    └── docs-index.md                 # full docs index + fallback (every page is <url>.md)
```

Lyzr spans **five hosts** — `agent-prod` (agents/chat/tools/workflows + sessions on `/v1`),
`rag-prod` (knowledge base, `/v3` + `/v4`), `rai-prod` (responsible AI), and
`voice-livekit` (voice agents), plus `wss://metrics` for live event tracing. The skill maps each.
Anything not pre-captured is reachable via the docs fallback: `lyzr.py docs "<path>"` (every
doc page is raw markdown at `<url>.md`).

## Quick start (helper CLI)

First time? See **[SETUP.md](SETUP.md)** for how to get your API key from Lyzr Studio and
set `LYZR_API_KEY` as an environment variable (macOS, Linux, Windows). Then, from a clone:

```bash
source ~/.zshrc   # loads LYZR_API_KEY (or however you set it — see SETUP.md)
S=skills/lyzr-agents/scripts/lyzr.py

python3 $S list                                   # list your agents
python3 $S create --file skills/lyzr-agents/examples/basic-agent.json
python3 $S chat <agent_id> "hello"                # talk to it
python3 $S chat <agent_id> "hello" --stream       # SSE streaming
python3 $S delete <agent_id>
```
When installed as a plugin, the same scripts live at
`${CLAUDE_PLUGIN_ROOT}/skills/lyzr-agents/scripts/`.

See `skills/lyzr-agents/SKILL.md` for the full, verified API reference.

## Status

Every endpoint and example in the skill has been exercised against the live API
(`https://agent-prod.studio.lyzr.ai/v3`) and confirmed working: agent CRUD, chat,
streaming, and structured JSON output.
