# Platform: build paths, connectors, eval, plans, accounts

Doc-derived overview of the Agent Lab platform surfaces (mostly Studio/UI concepts).

## Build paths (4 ways to build the same agents)
- **Studio** — low-code GUI. 11-step create flow (name → LLM/params → role/instructions →
  tools → examples → KB → features → create → test → deploy).
- **API** — REST (this skill's main focus). Base `agent-prod.studio.lyzr.ai`.
- **ADK** — Python SDK (`lyzr-adk`); see lyzr-adk.md.
- **Agent Builder** — conversational "describe it in English" builder; auto-generates the agent,
  OpenAPI 3.1 endpoint, and gRPC stubs.

## Data connectors (for KB / text-to-SQL)
- **Vector stores:** Qdrant, Weaviate, PG-Vector, Milvus (Zilliz), SingleStore — each needs a
  name + API key/token + URL/URI. Lyzr also offers managed `lyzr_qdrant`.
- **Graph:** Neo4j (URI `neo4j+s://...`, user `neo4j`, password, database).
- **Databases/warehouses:** Postgres, MySQL, Snowflake, Databricks, BigQuery, Redshift, MongoDB.
- **Files:** CSV, Excel, JSON.
Configure under Studio → connectors; then reference in a KB / semantic-model RAG config.

## Knowledge systems (3 types)
- **Classic KB** — vector RAG (PDF/DOCX/TXT/CSV/JSON/URLs). Studio limits: 5 files/session,
  15 MB/file. Strategies: basic, MMR, HyDE. (API: see rag.md)
- **Knowledge Graph** — Neo4j entities/relations. (API: see knowledge-graph-and-database.md)
- **Semantic Model** — database text-to-SQL. (API: see knowledge-graph-and-database.md)

## Manager agent (multi-agent)
Toggle "Manager Capability"; add sub-agents `{id, name, usage_description}`. API: the
`managed_agents` array on the agent object (see workflows.md). Manager delegates by the
`usage_description` metadata.

## Orchestration / workflow builder
Visual DAG: Input, AI Agent, API Call, Conditional, Router, Default Inputs. Auto-generates
JSON; execute via the workflow API (`run-dag` / `/v3/workflows/{id}/execute`), monitor via
WebSocket. (API: see workflows.md)

## Agent evaluation
- **Simulation & hardening** — clone agent, define Scenarios + Personas (World Model), run
  metrics (core + RAG-specific), auto-apply fixes and re-test up to N rounds.
- **Tracing** — OpenTelemetry. Root traces show id/duration/cost/tokens; filter by date
  (31-day max), agent, user, session; waterfall + execution logs.

## Plans (as documented)
- **Community** $0: 10 agents, 500 credits/mo, 5 KBs, 100 MB.
- **Pro** ~$79–99/mo: 25 agents, larger credit pool, 15 KBs, 1 GB.
- **Enterprise** custom: unlimited, SSO/SAML, 24/7, deployment flexibility.
- Credits: **1 credit = $1**. Model multipliers (× of GPT-4o-mini baseline): gpt-4o-mini 1×,
  Claude Haiku 2×, gpt-4o 16×, Claude Opus 15–20×. Tools = fixed cost; memory = free.
  Top-ups never expire; free/monthly reset monthly.

## Accounts / team / audit
- **API key:** sidebar → org name → "Account & API Key".
- **Billing:** Owner only → Manage → Manage Billing (Stripe).
- **Roles:** Owner (incl. billing), Admin (team + create, no billing), Member (create only).
- **Audit logs:** Admin/Owner → Manage → Admin → Audit Logs; filter by action/resource/result.

## Lyzr as MCP server (expose agents to Claude/Cursor)
```json
{ "lyzr-mcp-tool-call": { "command": "uvx", "args": ["lyzr-mcp-tool-call@latest"],
    "env": { "LYZR_API_KEY": "<key>", "LYZR_USER_ID": "<user>" } } }
```
Add to `claude_desktop_config.json` / `mcp.json`, restart; agents appear as tools.
