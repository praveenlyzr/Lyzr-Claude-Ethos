# Lyzr ADK — Python SDK

Code-first alternative to the REST API. **Verified live end-to-end** with `lyzr-adk` 0.1.9:
installed, `Studio(api_key=...)`, `create_agent(...)`, `.run(...)` (got a real reply),
`.delete()` — all worked. Same backend, so the REST facts in this skill still apply.

```bash
pip install lyzr-adk          # verified: v0.1.9
```
```python
from lyzr import Studio        # verified entry point (lyzr.studio.Studio)
studio = Studio(api_key="sk-...")   # or LYZR_API_KEY env
```
Confirmed `Studio` methods include sync + `a`-prefixed async variants: `create_agent`,
`get_agent`, `agents` (list), `clone_agent`, `delete_agent`, `bulk_delete_agents`,
`create_knowledge_base`, `create_context`, `create_rai_policy`, `create_schedule`,
`add_memory`. Exported classes incl. `Agent, KnowledgeBase, Tool, ToolRegistry, Context,
RAIPolicy, Cognis, Schedule, DallE, Gemini, Memory, Skill`.

### Verified live via the SDK
- **`create_agent` / `run` / `delete`** ✅ (run returned a real reply).
- **Knowledge base**: `create_knowledge_base(name=...)` → `kb.add_text(...)` → `kb.query("...", top_k=3)`
  returned the ingested fact with a score ✅; `kb.reset()/kb.delete()` ✅.
- **Streaming**: `for ch in agent.run(..., stream=True)` iterates chunks ✅.
- **Scheduler**: `create_schedule(user_id, agent_id, cron_expression, message=, timezone="UTC",
  max_retries=3, retry_delay=60)` → Schedule.id; `list_schedules()`, `delete_schedule(id)` ✅.
- **Cognis**: `Cognis(api_key=).add(messages=[...], owner_id=, agent_id=)` then `.search(query, owner_id=, agent_id=)`
  returned the stored memory ✅ (see cognis.md).

### Gotchas
- **Model names**: the SDK validates against its own catalog — `provider="gpt-4o-mini"` works;
  a bare REST string like `"claude-sonnet-4-6"` is rejected ("not found in any provider").
  Use SDK-known names or `provider/model` form.
- **Structured output**: `response_model=<Pydantic>` ran but `response.structured_output` came
  back `None` in testing — prefer the REST top-level `response_format` for reliable JSON.

## Agents
```python
agent = studio.create_agent(
    name="Assistant", provider="gpt-4o",      # or "claude-sonnet-4.5", "gemini-2.5-pro", "openai/gpt-4o"
    role="...", goal="...", instructions="...",
    temperature=0.7, top_p=0.9,
    memory=30,                                  # 1-50 msgs
    contexts=[ctx], response_model=MyModel,     # structured output (Pydantic)
    file_output=True, image_model="gemini-pro", # artifacts / images
    rai_policy=policy, knowledge_bases=[kb],
)

r = agent.run("question", session_id="user_1")   # session_id => memory across calls
print(r.response)                                  # text
data = r.structured_output                         # validated Pydantic (if response_model)
for f in r.files: f.download(f"./{f.name}")        # artifacts (f.format_type: pdf/docx/pptx/...)

for chunk in agent.run("...", stream=True):        # streaming
    print(chunk.delta, end="")                     # chunk.done, chunk.session_id, chunk.structured_data

studio.get_agent(id); studio.list_agents(provider="gpt-4o")
agent.update(temperature=0.5); agent.clone(new_name="v2"); agent.delete()
agent.add_memory(50); agent.add_tool(fn); agent.add_context(ctx); agent.add_rai_policy(p)
```

## Knowledge bases
```python
kb = studio.create_knowledge_base(name="docs", vector_store="qdrant",   # qdrant|weaviate|pg_vector|milvus|neptune
                                  embedding_model="text-embedding-3-large", llm_model="gpt-4o")
kb.add_pdf("m.pdf", chunk_size=1024, chunk_overlap=128)
kb.add_docx("p.docx"); kb.add_txt("f.txt"); kb.add_text("Q...A...", source="faq")
kb.add_website("https://docs.example.com", max_pages=100, max_depth=2)
kb.query("q", top_k=5, retrieval_type="basic", score_threshold=0.0)     # basic|mmr|hyde|time_aware
kb.list_documents(); kb.delete_documents([id]); kb.reset()
```

## Tools (Python functions)
```python
def get_weather(city: str) -> str:
    "Get current weather for a city"          # docstring => tool description; type hints => params
    return "..."
agent.add_tool(get_weather)

from lyzr.tools import Tool, ToolRegistry, LocalToolExecutor
t = Tool(name="search", description="...", parameters={...json-schema...}, function=fn)
# async tools supported (async def)
```

## Structured output / RAI / contexts
```python
from pydantic import BaseModel, Field
class Sentiment(BaseModel):
    sentiment: str; confidence: float
agent = studio.create_agent(name="A", provider="gpt-4o", response_model=Sentiment)

from lyzr.rai import PIIType, PIIAction
policy = studio.create_rai_policy(name="prod", toxicity_threshold=0.4, prompt_injection=True,
    pii_detection={PIIType.EMAIL: PIIAction.REDACT, PIIType.CREDIT_CARD: PIIAction.BLOCK},
    secrets_detection=True, nsfw_check=True)

ctx = studio.create_context(name="company", value="Acme Corp, founded 2020")
```

## Response object
`r.response` (str), `r.session_id`, `r.message_id`, `r.metadata`, `r.tool_calls`,
`r.files`, `r.has_files()`, `r.to_dict()`. Streaming chunk: `.content/.delta/.done/.session_id/.structured_data/.artifact_files`.

## Exceptions (`from lyzr.exceptions import ...`)
`AuthenticationError, ValidationError, NotFoundError, RateLimitError, APIError,
TimeoutError, InvalidResponseError, ToolNotFoundError`.

## Providers (SDK credential ids)
`lyzr_openai`, `lyzr_anthropic`, `lyzr_google`, `lyzr_groq`, `lyzr_perplexity`, `lyzr_aws-bedrock`.
