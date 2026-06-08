# Knowledge Graph (Neo4j) + Database / Text-to-SQL

Two advanced knowledge systems beyond vector RAG. Knowledge-graph endpoints exist on
rag-prod `/v4`; semantic-model (database) endpoints on agent-prod `/v3/semantic_model`.

## A. Knowledge Graph (Neo4j) — host `https://rag-prod.studio.lyzr.ai`

Creating a Neo4j-backed RAG config (`vector_db_credential_id: lyzr_neo4j`,
`vector_store_provider: "Neo4J"`) and calling the KG endpoints is **verified to validate
input** (`/v4/.../neo4j/text/` requires `rag_id`, `text`, **`source`**; graph GET works).
⚠️ But actual training with the **managed `lyzr_neo4j` credential fails** with
`500 "Processing Error: 'credentials'"` — KG training needs **your own Neo4j connector**
(Aura URI + user + password, configured under Studio → connectors). Endpoints below are
correct; training is gated on a real Neo4j credential.

| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | `/v4/knowledge_graph/neo4j/` | query `rag_id`; multipart `file`, `schema_prompt` (defines allowed nodes/relations), `extra_info` | `{message, nodes_created, relationships_created}` |
| POST | `/v4/knowledge_graph/neo4j/website/` | query `rag_id`; JSON `urls[]`, crawl params | `{message, pages_trained}` |
| POST | `/v4/knowledge_graph/neo4j/task/` | query `rag_id`; multipart `file`, `schema_prompt` | `"Task successfully started."` (async) |
| POST | `/v4/knowledge_graph/neo4j/text/` | JSON `rag_id`, `text`, `schema_prompt` | async start |
| GET | `/v4/knowledge_graph/neo4j/graph/?rag_id=&limit=50` | — | `{nodes:[{id,label,properties}], edges:[{source,target,type}]}` |
| POST | `/v4/knowledge_graph/neo4j/{rag_id}/deduplicate/` | `{}` | dedup task started |

`schema_prompt` is the key knob: it tells the extractor which node types and relationship
types are allowed (e.g. "Nodes: Person, Company. Relations: WORKS_AT").

## B. Database / Semantic Model (Text-to-SQL) — host `https://agent-prod.studio.lyzr.ai`

`GET /v3/semantic_model/documentation_agents` verified live (200 → `{"documentation_agents":[]}`).
Flow: register a DB data connector (Studio/connectors) → connect it to a RAG config →
document tables → the agent answers natural-language questions as SQL.

| Method | Path | Notes |
|--------|------|-------|
| POST | `/v3/semantic_model/connect_database/{rag_config_id}/{database_id}` | Link a connected DB to a RAG config |
| GET | `/v3/semantic_model/list_tables/{rag_config_id}/{database_id}` | `{schemas_and_tables}` |
| GET | `/v3/semantic_model/table_preview/{rag_config_id}/{database_id}/{table_name}` | sample rows |
| POST | `/v3/semantic_model/documentation_agents` | Create a schema-doc agent: `{name, provider_id, model_id, top_p, temperature, llm_credential_id?}` |
| GET | `/v3/semantic_model/documentation_agents` | List (verified) |
| POST | `/v3/semantic_model/save_documentation/{rag_config_id}/{table_name}` | Save column descriptions: `{descriptions:{table_name, table_description, columns:[{name,description,type}]}, table_preview:[...]}` |

Supported DBs (via connectors): PostgreSQL, MySQL, Snowflake, Databricks, BigQuery,
Redshift, MongoDB, plus file sources (CSV/Excel/JSON). Use a `semantic_data_model: true`
RAG config for this path.
