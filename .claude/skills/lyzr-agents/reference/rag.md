# Knowledge Base / RAG API

⚠️ **RAG runs on a different host:** `https://rag-prod.studio.lyzr.ai` (NOT agent-prod).
Auth: `x-api-key`. Paths use `/v3` and require a **trailing slash**.

**Entire lifecycle verified live** (create → ingest → retrieve → attach-to-agent →
agent-retrieves-in-chat → reset → delete). Credential IDs and feature shapes below are real.

## The credentials you need (Lyzr-managed — no own keys)

From live configs:
- `llm_credential_id`: `lyzr_openai`
- `embedding_credential_id`: `lyzr_openai`
- `vector_db_credential_id`: `lyzr_qdrant` (managed Qdrant) — or `lyzr_neo4j` for a graph store
- `vector_store_provider`: `"Qdrant [Lyzr]"` (string, with the space + brackets) — or `"Neo4J"`
- `llm_model`: `gpt-4o-mini`; `embedding_model`: `text-embedding-ada-002` (or `text-embedding-3-large`)

## Config management (verified)

| Method | Path | Notes |
|--------|------|-------|
| POST | `/v3/rag/` | Create. Returns the config with its id in **`id`**. ✅ |
| GET | `/v3/rag/user/{user_id}/` | List. `{"configs": [...]}`; each id is in **`_id`** here. ✅ |
| GET | `/v3/rag/{rag_id}/` | Get one (id field is `id`). ✅ |
| PUT | `/v3/rag/{rag_id}/` | Update (full body) → `{"success":true}`. ✅ (changed description live) |
| DELETE | `/v3/rag/{rag_id}/reset/` | Wipe ingested docs → `{"message":"Collection deleted successfully"}`. |
| DELETE | `/v3/rag/{rag_id}/` | Delete config → `{"success": true}`. |

`{user_id}` accepts your email; note stored configs show `user_id` = the **api key** string.

**Create body (verified):**
```json
{
  "user_id": "you@example.com",
  "llm_credential_id": "lyzr_openai",
  "embedding_credential_id": "lyzr_openai",
  "vector_db_credential_id": "lyzr_qdrant",
  "vector_store_provider": "Qdrant [Lyzr]",
  "collection_name": "my_kb_001",
  "llm_model": "gpt-4o-mini",
  "embedding_model": "text-embedding-ada-002",
  "description": "...",
  "semantic_data_model": false,
  "meta_data": {}
}
```

## Ingestion / training (txt, pdf, docx, website — ALL verified live)

`rag_id` is a **query param**. Files are **multipart**; website is JSON.
```bash
curl -X POST "https://rag-prod.studio.lyzr.ai/v3/train/txt/?rag_id=$RID" \
  -H "x-api-key: $LYZR_API_KEY" -F "file=@kb.txt;type=text/plain"
# -> {"message":"TXT parsing and training completed successfully","rag_id":"...","document_count":1}
```

| Method | Path | Query | Body | Verified |
|--------|------|-------|------|----------|
| POST | `/v3/train/txt/` | `rag_id` | multipart `file`, `data_parser` (default `txt_parser`), `extra_info` | ✅ |
| POST | `/v3/train/pdf/` | `rag_id` | multipart `file`, `data_parser` (default `llmsherpa`), `extra_info` | ✅ |
| POST | `/v3/train/docx/` | `rag_id` | multipart `file`, `data_parser` (default `docx2txt`), `extra_info` | ✅ |
| POST | `/v3/train/website/` | `rag_id` | JSON `urls[]`, `max_crawl_pages`, `max_crawl_depth`, `chunk_size`, `chunk_overlap`, `dynamic_content_wait_secs`, `actor`, `crawler_type` | ✅ |

All return `{message, rag_id, document_count}`. (Verified by ingesting a PDF, a DOCX, a
.txt, and a crawled web page into one KB and retrieving format-specific facts back.)
On macOS you can make test files with `textutil -convert docx in.txt -output out.docx`
and `cupsfilter in.txt > out.pdf`.

### Parse-only (no storage) — verified

For chunking/embedding **without** persisting to a KB (build custom pipelines):
| Method | Path (host: rag-prod) | Body |
|--------|------|------|
| POST | `/v3/parse/text/` | JSON `{"data":[{"text","source","extra_info"}], "chunk_size", "chunk_overlap"}` → `{"documents":[...]}` ✅ |
| POST | `/v3/parse/csv/` | multipart `file`, `source_column` (required) — text from that column, other columns become metadata → `{"documents":[...]}` ✅ |
| POST | `/v3/parse/website/` | JSON like train/website (`urls`, `source`, crawl + chunk params) → `{"documents":[...]}` ✅ |
| POST | `/v3/parse/pdf/` | multipart `file`, `chunk_size`, `chunk_overlap`, `data_parser`, `extra_info` (doc-derived) |

For **knowledge graphs** (Neo4j) and **database/text-to-SQL** (semantic model), see
[`knowledge-graph-and-database.md`](knowledge-graph-and-database.md).

## Documents + retrieval (verified)

```
GET /v3/rag/documents/{rag_id}/
-> [ {"type":"file","name":"storage/kb.txt","source_key":"storage/kb.txt","live_source":null} ]

GET /v3/rag/{rag_id}/retrieve/
   ?query=<text>&top_k=<int>
   &retrieval_type=basic|mmr|hyde|time_aware
   &score_threshold=<0..1>&lambda_param=<0..1>&time_decay_factor=<float>
-> {"results":[ {"id","score","metadata":{source,file_name,...},"text":"..."} ]}
```
(`lambda_param` = MMR tradeoff; `time_decay_factor` = time_aware weighting.)

## Attaching a KB to an agent ⭐ (verified end-to-end)

Add a `KNOWLEDGE_BASE` entry to the agent's **`features`** array. The agent then
retrieves from the KB automatically at chat time — confirmed: an agent answered a fact
that existed only in the ingested doc.

```json
{
  "features": [
    {
      "type": "KNOWLEDGE_BASE",
      "config": {
        "lyzr_rag": {
          "base_url": "https://rag-prod.studio.lyzr.ai",
          "rag_id": "<rag_id>",
          "rag_name": "<collection_name>",
          "params": { "top_k": 5, "retrieval_type": "basic", "score_threshold": 0 }
        },
        "agentic_rag": []
      },
      "priority": 0
    }
  ]
}
```

Related feature (also seen on live agents) — conversation memory:
```json
{ "type": "MEMORY", "config": { "max_messages_context_count": 50 }, "priority": 0 }
```
`features` accepts multiple entries (e.g. MEMORY + KNOWLEDGE_BASE together).

### Confidence test (verified): dynamic doc → KB → agent

End-to-end proof that Claude can add a doc and have an agent retrieve it: created a KB,
ingested a doc containing `promo code ZEPHYR-9981-QUOKKA`, wired it to a *fresh, minimal*
agent (instructions just "answer using your knowledge base"), then asked "what promo code
should I use?" → the agent answered **ZEPHYR-9981-QUOKKA** (a token that existed nowhere but
the doc). `scripts/rag_smoke_test.sh` automates this pattern.

⚠️ **Caveat for such tests:** the model's safety layer will *refuse* to surface content
framed as "secret / confidential / internal / do not share" even when retrieval succeeds
(observed: the agent acknowledged having the info but declined). Use neutral, clearly
shareable facts (a promo code, a product spec, a person's name) to test *retrieval* itself.
