# Models & providers

There is **no live models/providers GET endpoint** (all `/v3/models` etc. → 405).
Use this list. `provider_id` casing on the agent object is **capitalized**
(`OpenAI`, `Anthropic`, `Google`) — that's what live agents store, even though the docs
sometimes write lowercase.

## Verified-in-use combos (from live agents — safe defaults)

| provider_id | model | llm_credential_id |
|-------------|-------|-------------------|
| `Anthropic` | `claude-sonnet-4-6` | `lyzr_anthropic` |
| `OpenAI` | `gpt-4.1`, `gpt-4o`, `gpt-4o-mini`, `gpt-5`, `o3` | `lyzr_openai` |
| `OpenAI` | `gpt-5-nano` | `lyzr-default` |
| `Google` | `gemini-2.0-flash`, `gemini/gemini-3.1-flash-lite` | `lyzr_google` |

The `lyzr_*` credentials are **shared, Lyzr-managed** keys — you don't need your own
provider API key to use them.

## Catalog from docs (provider → models)

- **OpenAI:** gpt-5, gpt-5.1, gpt-5-mini, gpt-5-nano, o3, o4-mini, gpt-4.1, gpt-4o, gpt-4o-mini
- **Anthropic:** claude-opus-4-5, claude-sonnet-4-5, claude-opus-4-1/4-0, claude-sonnet-4-0, claude-3-7-sonnet-latest, claude-3-5-haiku-latest
- **Google:** gemini-3-pro-preview, gemini-3-flash-preview, gemini-2-5-pro/flash/flash-lite, gemini-2-0-flash/flash-lite
- **Groq:** llama-3.3-70b-versatile, llama-3.1-8b-instant, llama-4-scout/maverick-17b, gpt-oss-20b/120b, moonshot-kimi-k2-instruct
- **Perplexity:** sonar, sonar-pro, sonar-reasoning(-pro), sonar-deep-research, r1-1776
- **AWS Bedrock:** nova-pro/lite/micro, claude-3-x variants, llama-3-x variants, mistral-* (Bedrock requires your own credential configured)

When unsure which to use, default to `Anthropic` / `claude-sonnet-4-6` / `lyzr_anthropic`.
Pick lighter models (gpt-4o-mini, gemini flash) for high-volume/cheap; heavier (opus, o3)
for hard reasoning. Credits ≈ $1 each; cost scales with model + tokens.
