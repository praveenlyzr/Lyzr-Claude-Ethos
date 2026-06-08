#!/usr/bin/env bash
# Comprehensive end-to-end RAG smoke test for the Lyzr API.
# Creates a throwaway KB + agent, ingests 2 docs, runs retrieval + chat
# grounding/negative/cross-doc checks, updates KB params, then cleans up.
# Requires: LYZR_API_KEY in env. Usage: bash rag_smoke_test.sh
set -uo pipefail

AGENT="https://agent-prod.studio.lyzr.ai"
RAG="https://rag-prod.studio.lyzr.ai"
H=(-H "x-api-key: $LYZR_API_KEY" -H "Content-Type: application/json")
U="${LYZR_USER_ID:-smoke@lyzr.ai}"
PASS=0; FAIL=0
RID=""; AID=""

j() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d$1)" 2>/dev/null; }
check() { # check "label" "haystack" "needle"
  if grep -qi "$3" <<<"$2"; then echo "  PASS: $1"; PASS=$((PASS+1));
  else echo "  FAIL: $1 (looking for '$3')"; echo "        got: ${2:0:160}"; FAIL=$((FAIL+1)); fi
}
ask() { curl -s -X POST "$AGENT/v3/inference/chat/" "${H[@]}" \
  -d "{\"user_id\":\"$U\",\"agent_id\":\"$AID\",\"session_id\":\"$1\",\"message\":\"$2\"}" | j "['response']"; }

cleanup() {
  echo "== cleanup =="
  [ -n "$AID" ] && curl -s -X DELETE "$AGENT/v3/agents/$AID" "${H[@]}" >/dev/null && echo "  deleted agent $AID"
  if [ -n "$RID" ]; then
    curl -s -X DELETE "$RAG/v3/rag/$RID/reset/" "${H[@]}" >/dev/null
    curl -s -X DELETE "$RAG/v3/rag/$RID/" "${H[@]}" >/dev/null && echo "  deleted rag $RID"
  fi
}
trap cleanup EXIT

echo "== 1. create RAG config =="
RID=$(curl -s -X POST "$RAG/v3/rag/" "${H[@]}" -d "{
  \"user_id\":\"$U\",\"llm_credential_id\":\"lyzr_openai\",\"embedding_credential_id\":\"lyzr_openai\",
  \"vector_db_credential_id\":\"lyzr_qdrant\",\"vector_store_provider\":\"Qdrant [Lyzr]\",
  \"collection_name\":\"smoke_kb_$RANDOM\",\"llm_model\":\"gpt-4o-mini\",
  \"embedding_model\":\"text-embedding-ada-002\",\"description\":\"smoke test\",
  \"semantic_data_model\":false,\"meta_data\":{}}" | j "['id']")
[ -n "$RID" ] && { echo "  rag_id=$RID"; PASS=$((PASS+1)); } || { echo "  FAIL: no rag_id"; FAIL=$((FAIL+1)); exit 1; }

echo "== 2. ingest two separate documents =="
cat > /tmp/smoke_a.txt <<'EOF'
ACME Robotics product facts. The flagship robot is the Atlas-9 courier drone.
Its mascot is a golden otter named Plink. The internal magic number is 8675309.
EOF
cat > /tmp/smoke_b.txt <<'EOF'
ACME Robotics policy facts. The refund window is 14 days from delivery.
The company CEO is Dr. Mira Vance and headquarters are in Lisbon, Portugal.
EOF
for f in a b; do
  R=$(curl -s -X POST "$RAG/v3/train/txt/?rag_id=$RID" -H "x-api-key: $LYZR_API_KEY" -F "file=@/tmp/smoke_$f.txt;type=text/plain")
  check "ingest doc $f" "$R" "completed successfully"
done

echo "== 3. documents list shows both files =="
DOCS=$(curl -s "$RAG/v3/rag/documents/$RID/" "${H[@]}")
N=$(python3 -c "import sys,json;print(len(json.load(sys.stdin)))" <<<"$DOCS" 2>/dev/null)
[ "${N:-0}" -ge 2 ] && { echo "  PASS: $N docs listed"; PASS=$((PASS+1)); } || { echo "  FAIL: expected >=2 docs, got ${N:-0}"; FAIL=$((FAIL+1)); }

echo "== 4. retrieval across types =="
for t in basic mmr hyde; do
  R=$(curl -s "$RAG/v3/rag/$RID/retrieve/?query=who%20is%20the%20mascot&top_k=3&retrieval_type=$t&score_threshold=0.0&lambda_param=0.5&time_decay_factor=0.0" "${H[@]}")
  check "retrieve[$t] finds Plink" "$R" "Plink"
done

echo "== 5. create agent wired to the KB =="
AID=$(curl -s -X POST "$AGENT/v3/agents/" "${H[@]}" -d "{
  \"name\":\"RAG Smoke Agent\",\"description\":\"smoke\",
  \"agent_role\":\"Answer ONLY from the knowledge base.\",
  \"agent_instructions\":\"Use the knowledge base to answer. If the answer is not in the knowledge base, reply exactly: I don't know.\",
  \"agent_goal\":\"grounded answers\",
  \"features\":[{\"type\":\"KNOWLEDGE_BASE\",\"config\":{\"lyzr_rag\":{\"base_url\":\"$RAG\",\"rag_id\":\"$RID\",\"rag_name\":\"smoke\",\"params\":{\"top_k\":5,\"retrieval_type\":\"basic\",\"score_threshold\":0}},\"agentic_rag\":[]},\"priority\":0}],
  \"tools\":[],\"llm_credential_id\":\"lyzr_anthropic\",\"provider_id\":\"Anthropic\",
  \"model\":\"claude-sonnet-4-6\",\"top_p\":0.95,\"temperature\":0.1}" | j "['agent_id']")
[ -n "$AID" ] && { echo "  agent_id=$AID"; PASS=$((PASS+1)); } || { echo "  FAIL: no agent_id"; FAIL=$((FAIL+1)); exit 1; }
sleep 2

echo "== 6. grounding: facts that live ONLY in the KB =="
check "doc-A fact (magic number)" "$(ask s-magic 'What is the internal magic number?')" "8675309"
check "doc-B fact (CEO)"          "$(ask s-ceo   'Who is the CEO?')"                      "Mira Vance"
check "doc-B fact (refund)"       "$(ask s-ref   'How many days is the refund window?')"  "14"

echo "== 7. cross-document question (needs both docs) =="
X=$(ask s-cross 'Name the mascot and the city of the headquarters.')
check "cross-doc: mascot" "$X" "Plink"
check "cross-doc: city"   "$X" "Lisbon"

echo "== 8. negative: fact NOT in the KB -> should refuse =="
NEG=$(ask s-neg 'What is the office WiFi password?')
check "no-hallucination (says don't know)" "$NEG" "don't know"

echo "== 9. update KB params on the agent (PUT) =="
GET=$(curl -s "$AGENT/v3/agents/$AID" "${H[@]}")
UPD=$(python3 - "$GET" <<'PY'
import sys,json
a=json.loads(sys.argv[1])
for f in a.get("features",[]):
    if f.get("type")=="KNOWLEDGE_BASE":
        f["config"]["lyzr_rag"]["params"]["top_k"]=8
body={k:a[k] for k in ("name","description","agent_role","agent_instructions","agent_goal","features","provider_id","model","top_p","temperature") if k in a}
body["llm_credential_id"]=a.get("llm_credential_id","lyzr_anthropic")
body["tools"]=a.get("tool") or []
print(json.dumps(body))
PY
)
R=$(curl -s -X PUT "$AGENT/v3/agents/$AID" "${H[@]}" -d "$UPD")
check "PUT update KB top_k" "$R" "updated successfully"
V=$(curl -s "$AGENT/v3/agents/$AID" "${H[@]}" | python3 -c "import sys,json
a=json.load(sys.stdin)
print(next((f['config']['lyzr_rag']['params']['top_k'] for f in a.get('features',[]) if f.get('type')=='KNOWLEDGE_BASE'),'?'))" 2>/dev/null)
[ "$V" = "8" ] && { echo "  PASS: top_k persisted as 8"; PASS=$((PASS+1)); } || { echo "  FAIL: top_k=$V"; FAIL=$((FAIL+1)); }

echo "== 10. still answers after update =="
check "post-update grounding" "$(ask s-after 'Who is the CEO?')" "Mira Vance"

echo "============================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================"
[ "$FAIL" -eq 0 ]
