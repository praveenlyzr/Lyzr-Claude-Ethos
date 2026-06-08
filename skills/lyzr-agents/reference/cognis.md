# Cognis — persistent agent memory layer

Long-term memory that extracts facts from conversations and retrieves them semantically
(hybrid vector + BM25, RRF fusion). **Verified live via `lyzr-adk`:** `Cognis(api_key=).add(
messages=[{role,content}], owner_id="u1", agent_id="a1")` → `{success:true, "Added 2 messages"}`,
then `.search("what color does the user prefer", owner_id="u1", agent_id="a1")` returned the
stored memory (`CognisSearchResult(content="...teal...", score=1.0)`). Ops/signatures below.

Two flavors:
- **Hosted** — `pip install lyzr-adk`, one key (`LYZR_API_KEY`). Async, summaries, 6 retrieval
  strategies, cross-session. `Cognis(api_key="sk-...")`.
- **Open-source** — `pip install lyzr-cognis`, local SQLite + Qdrant at `~/.cognis/`, needs
  Gemini (embeddings) + OpenAI (extraction) keys. Sync only, COGNIS strategy only.

## Scope model (3 levels)
| Level | id | Scope |
|-------|----|-------|
| User/tenant | `owner_id` | all agents + sessions |
| Agent | `agent_id` | all sessions of that agent |
| Conversation | `session_id` | one conversation |
Extracted **facts** are global to `(owner_id, agent_id)`; raw **messages** are scoped to the session.

## Operations (hosted; async = `a`-prefix, e.g. `aadd`)
```python
cog.add(messages=[{"role","content"}], owner_id=, agent_id=, session_id=)
    # -> {success, session_id, memories_created}; LLM extracts + auto-categorizes + dedupes (0.85)
cog.search(query, owner_id=, agent_id=, session_id=, limit=10, cross_session=False)
    # -> [{id, content, score, owner_id, agent_id, session_id, metadata, timestamp}]
cog.get(owner_id=, agent_id=, session_id=, limit=50, offset=0, include_historical=False, cross_session=False)
cog.get_memory(memory_id, owner_id=)
cog.update(memory_id, content=, metadata=, owner_id=)      # increments version
cog.delete(memory_id, owner_id=); cog.delete_session(owner_id, session_id, agent_id=)
cog.context(current_messages, owner_id=, session_id=, max_short_term_messages=30,
            enable_long_term_memory=True, cross_session=False)
    # -> {context_string, short_term:[...], long_term:[...]}  (LLM-ready merge)
cog.store_summary(owner_id, session_id, content, messages_covered_count, agent_id=)
cog.get_current_summary(owner_id, session_id); cog.search_summaries(owner_id, query, ...)
# scope switching: m.set_owner(), m.set_agent(), m.new_session()
```

## Retrieval strategies (hosted)
`COGNIS` (default: vector+BM25+RRF+recency), `FOUR_WAY_TEMPR` (adds graph), `MULTI_QUERY_RAG`
(query variants + HyDE), `SINGLE_QUERY` (fast vector-only), `SIMPLEMEM_ADAPTIVE`, `RFM_EVIDENCE_POOL`.

Tune via `CognisConfig(vector_weight=0.7, bm25_weight=0.3, recency_half_life=120, embedding_dimensions=768)`.
13 built-in memory categories (identity, work_career, preferences, goals, ...); customizable.

## Claude-Cognis (persistent memory for Claude Code)
Plugin that auto-loads relevant memory at session start and saves a compressed summary at the
end. Config: `~/.cognis-claude/settings.json` (global) / `.claude/.cognis-claude/config.json`
(project: `apiKey, ownerId, agentId`). Env: `LYZR_API_KEY`, `COGNIS_PRIVATE`,
`COGNIS_ISOLATE_WORKTREES`, `COGNIS_CUSTOM_URL`. Commands: `/claude-cognis:recall`,
`:memory-stats`, `:index`. Personal memory keyed per user+project; team memory shared per repo.
