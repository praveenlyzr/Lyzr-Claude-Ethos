# Responsible / Safe AI API

⚠️ **RAI runs on its own host:** `https://rai-prod.studio.lyzr.ai` (NOT agent-prod —
`agent-prod/.../rai/policies` returns 405). Auth: `x-api-key`. All endpoints below
were hit live and returned **200**.

## Guardrail checkers (verified)

Note the path typo in the live API — it really is `dectector`.

### Prompt injection
```
POST https://rai-prod.studio.lyzr.ai/prompt-injection-dectector/
{ "input_text": "...", "agent_id": "<id>", "session_id": "<id>", "run_id": "optional" }
```
Response: `{"message": "INJECTION"|"...", "details": {"is_injection": bool, "confidence": 0-100}, "status_code": 200}`
(Verified: "Ignore all previous instructions..." → `is_injection: true, confidence: 100`.)

### Toxicity
```
POST https://rai-prod.studio.lyzr.ai/toxicity-meter/
{ "input_text": "...", "agent_id": "<id>", "session_id": "<id>", "run_id": "optional" }
```
Response: `{"message": "NON_TOXIC"|"TOXIC", "details": {"is_toxic": bool, "confidence": 0-100}, "status_code": 200}`

## Policies — create / list / delete all verified

```
POST   https://rai-prod.studio.lyzr.ai/v1/rai/policies        # create → 200, returns {_id, ...}
GET    https://rai-prod.studio.lyzr.ai/v1/rai/policies        # list → {"policies":[...]}
DELETE https://rai-prod.studio.lyzr.ai/v1/rai/policies/{id}   # → 200 {"success":true}
```

Minimal verified create body:
```json
{ "name": "My Policy", "description": "...", "user_id": "you@example.com",
  "toxicity_check": { "enabled": true, "threshold": 0.4 },
  "prompt_injection": { "enabled": true, "threshold": 0.3 },
  "secrets_detection": { "enabled": true, "action": "mask" } }
```
Full policy object fields (from a real policy): `allowed_topics`/`banned_topics`
(`{enabled, topics:[]}`), `keywords` (`{enabled, keywords:[]}`), `toxicity_check`/
`prompt_injection` (`{enabled, threshold}`), `secrets_detection` (`{enabled, action:"mask"}`),
`pii_detection` (`{enabled, types:{CREDIT_CARD|EMAIL_ADDRESS|PHONE_NUMBER|PERSON|...: "disabled"|...}}`),
plus `fairness_and_bias`, `gibberish_text`, `nsfw_check`, `valid_openapi_spec`, `valid_sql`,
`bedrock_guardrail`, `vertex_guardrail`, `opa_guardrail`, `cedar_guardrail`.
⚠️ `banned_topics.topics[]` / `allowed_topics.topics[]` items must be **objects**, not strings
(a bare string → 422). Leave them `[]` unless you have the object shape.

Binding a policy to an agent: the agent JSON on this account doesn't expose the field, so set
it in Studio or via the SDK (`rai_policy=` / `agent.add_rai_policy(...)`). The guardrail
checkers above work standalone regardless.
