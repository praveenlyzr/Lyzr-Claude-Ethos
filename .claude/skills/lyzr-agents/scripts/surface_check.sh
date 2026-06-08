#!/usr/bin/env bash
# Full-surface drift detector: re-checks every endpoint the skill claims is verified,
# across all hosts, and flags regressions if Lyzr's API changes. Read-only/no-write except
# one create+delete agent round-trip. Requires LYZR_API_KEY. Usage: bash surface_check.sh
set -uo pipefail
AGENT="https://agent-prod.studio.lyzr.ai"; RAG="https://rag-prod.studio.lyzr.ai"
RAI="https://rai-prod.studio.lyzr.ai"; VOICE="https://voice-livekit.studio.lyzr.ai/v1"
U="${LYZR_USER_ID:-praveen@lyzr.ai}"; PASS=0; FAIL=0
code(){ curl -s -o /dev/null -w "%{http_code}" -X "$1" "$2" -H "x-api-key: $LYZR_API_KEY" "${@:3}"; }
expect(){ # expect METHOD URL EXPECTED_CODE LABEL [curl args...]
  local m=$1 u=$2 want=$3 label=$4; shift 4
  local got; got=$(code "$m" "$u" "$@")
  if [ "$got" = "$want" ]; then echo "  ok   [$got] $label"; PASS=$((PASS+1))
  else echo "  DRIFT[$got≠$want] $label  ($m $u)"; FAIL=$((FAIL+1)); fi
}
echo "== agent-prod /v3 =="
expect GET  "$AGENT/v3/agents/" 200 "list agents"
expect GET  "$AGENT/v3/tools/" 200 "list tools (returns {})"
expect GET  "$AGENT/v3/providers/tools/all" 200 "ready-tool catalog"
expect GET  "$AGENT/v3/workflows/" 200 "list workflows"
expect GET  "$AGENT/v3/semantic_model/documentation_agents" 200 "semantic doc-agents"
echo "== sessions /v1 (agent-prod) =="
SID=$(curl -s "$AGENT/v1/agents/../" -H "x-api-key: $LYZR_API_KEY" >/dev/null 2>&1; echo "test-session-001")
expect GET  "$AGENT/v1/agent/6a20cac3bb362f152d6356e3/sessions" 200 "sessions by agent"
echo "== rag-prod =="
expect GET  "$RAG/v3/rag/user/$U/" 200 "list rag configs"
echo "== rai-prod =="
expect GET  "$RAI/v1/rai/policies" 200 "list RAI policies"
expect POST "$RAI/toxicity-meter/" 200 "toxicity checker" \
  -H "Content-Type: application/json" -d '{"input_text":"hello","agent_id":"x","session_id":"y"}'
echo "== voice-livekit /v1 =="
expect GET  "$VOICE/agents" 200 "list voice agents"
expect GET  "$VOICE/config/pipeline-options" 200 "voice pipeline options"
echo "== known-dead (should STAY non-200; flips = the API was fixed) =="
expect POST "$AGENT/v3/tools/openapi/x/execute?path=/&method=get" 405 "tool execute (known 405)" \
  -H "Content-Type: application/json" -d '{}'
echo "== agent CRUD round-trip =="
AID=$(curl -s -X POST "$AGENT/v3/agents/" -H "x-api-key: $LYZR_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"Surface Check","agent_role":"x","agent_instructions":"Reply OK.","agent_goal":"x","features":[],"llm_credential_id":"lyzr_anthropic","provider_id":"Anthropic","model":"claude-sonnet-4-6","top_p":0.95,"temperature":0.2}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('agent_id',''))" 2>/dev/null)
[ -n "$AID" ] && { echo "  ok   [create] agent $AID"; PASS=$((PASS+1)); } || { echo "  DRIFT create agent"; FAIL=$((FAIL+1)); }
if [ -n "$AID" ]; then
  expect POST "$AGENT/v3/inference/chat/" 200 "chat" -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$U\",\"agent_id\":\"$AID\",\"session_id\":\"sc\",\"message\":\"hi\"}"
  expect DELETE "$AGENT/v3/agents/$AID" 200 "delete agent"
fi
echo "======================================================"
echo "SURFACE CHECK: $PASS ok, $FAIL drift"
echo "======================================================"
[ "$FAIL" -eq 0 ]
