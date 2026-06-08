# Lyzr overview, concepts & glossary

Doc-derived background for answering "what is / why / how does Lyzr…" questions.

## What Lyzr is
An enterprise agent framework for "secure, safe, responsible" GenAI apps. Configurable
agents + pre-built RAG (600+ pipeline variations) + built-in governance (bias, toxicity,
PII, audit) + multi-LLM (OpenAI, Anthropic, Google, Bedrock, Perplexity, Groq) with runtime
switching. Build via Studio (no-code), REST API, ADK (Python), or conversational Agent Builder.
Enterprise: RBAC, SSO/SAML, encryption, HIPAA/SOC2.

## What you can build
Chat agents (stateful, memory) · Knowledge search (cited retrieval) · RAG apps · QA bots
(single-turn) · Text-to-SQL agents · Multi-agent workflows (DAG orchestration **or**
managerial orchestration).

## Core components
Agent Builder · Knowledge Base · Tools · Features (memory, RLHF, multi-LLM, safety) ·
Multi-agent orchestration · Studio · REST API.

## Glossary (selected)
- **Agent** — autonomous configured AI unit. **Embeddings** — semantic vectors.
- **RAG** — retrieve external docs + generate. **Chain of Thought** — explicit reasoning steps.
- **DAG orchestration** — dependency-ordered multi-agent run. **Managerial orchestration** —
  manager decomposes + delegates at runtime.
- **AIMS** — Agent management/governance console. **RBAC** — role-based access.
- **Groundedness / Reflection / Prompt-injection / PII redaction** — built-in safety checks.

## Getting the API key
studio.lyzr.ai → sidebar → org name → "Account & API Key". Header is `x-api-key`.
(In this environment it's already in `~/.zshrc` as `LYZR_API_KEY`.)

## Credits
1 credit = $1. Free tier 5/mo. Consumption is token × model-multiplier (gpt-4o-mini 1×,
Haiku 2×, gpt-4o 16×, Opus 15–20×); tools fixed; memory free.

## Support / community
support@lyzr.ai · contact@lyzr.ai (sales) · GitHub github.com/LyzrCore/lyzr-framework ·
YouTube @LyzrAI · full index docs.lyzr.ai/llms.txt.
