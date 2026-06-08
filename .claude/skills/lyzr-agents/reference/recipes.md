# Recipes — task-oriented playbooks

Goal-first guides that compose the verified primitives. Each maps to reference files + the
`scripts/lyzr.py` helper. All flows here are built from live-verified endpoints.

## 1. Support bot with knowledge + memory
One command: `bash scripts/recipe_support_bot.sh <kb_name> <doc_file>` (creates KB, ingests
the doc, spins up an agent with `KNOWLEDGE_BASE` + `MEMORY`, prints the agent id). Manually:
```bash
S=scripts/lyzr.py
RID=$(python3 $S rag-create support_kb | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
python3 $S rag-train "$RID" ./faq.pdf            # txt/pdf/docx/website all work
# create agent.json with features: [MEMORY, KNOWLEDGE_BASE(rag_id=$RID)] — see examples/knowledge-base-agent.json
python3 $S create --file agent.json
python3 $S chat <agent_id> "How do I reset my password?"
```
Agent retrieves from the KB automatically. Verified end-to-end (see rag.md confidence test).

## 2. Multi-agent manager
Create specialized sub-agents, then a manager whose `managed_agents[]` lists them with a
sharp `usage_description` (that's what drives routing). See `examples/manager-agent.json`
and workflows.md. Verified: routed math vs. poetry to the right sub-agent.

## 3. Structured JSON extractor
Set `response_format` (json_schema) on the agent → `response` is a JSON string matching the
schema. See `examples/structured-output-agent.json` and SKILL.md "Structured output". Prefer
this REST field over the SDK's `response_model` (which didn't populate `structured_output`
cleanly in testing).

## 4. File-generating agent (PDF/DOCX/PPTX)
Set top-level `file_output: true`. Ask for a document → the chat response includes
`module_outputs.artifact_files: [{file_url, artifact_id, name, format_type}]`; download
`file_url`. Verified: generated + downloaded a real PDF. (Image output needs a dedicated
image `credential_id` — the shared one fails generation.)

## 5. Guardrailed agent (Responsible AI)
Create a policy (responsible-ai.md) and/or call the standalone checkers
`/prompt-injection-dectector/` and `/toxicity-meter/` (rai-prod) before/after inference.
Bind a policy to an agent in Studio or via the SDK (`rai_policy=`).

## 6. Recurring agent (scheduler) — via SDK
```python
from lyzr import Studio
s = Studio(api_key=KEY)
sch = s.create_schedule(user_id="you@x.com", agent_id=AID,
                        cron_expression="0 9 * * *", message="daily digest")
s.list_schedules(); s.delete_schedule(sch.id)     # verified create/list/delete
```

## 7. Persistent cross-session memory (Cognis) — via SDK
```python
from lyzr import Cognis
cog = Cognis(api_key=KEY)
cog.add(messages=[{"role":"user","content":"I prefer teal"}], owner_id="u1", agent_id="a1")
cog.search("what color does the user prefer", owner_id="u1", agent_id="a1")   # verified
```

## 8. Regression check before shipping
`bash scripts/surface_check.sh` — re-verifies every claimed endpoint across all hosts and
flags drift (incl. "known-dead" endpoints flipping back to alive). Run after Lyzr API updates.

## Pick a model
Cheap/fast: `gpt-4o-mini`, `gemini-2.0-flash`. Balanced: `claude-sonnet-4-6`. Heavy reasoning:
`o3`, Claude Opus. Defaults in this skill: `Anthropic / claude-sonnet-4-6 / lyzr_anthropic`.
(SDK wants SDK-known model names, e.g. `gpt-4o-mini`, not always the REST string.)
