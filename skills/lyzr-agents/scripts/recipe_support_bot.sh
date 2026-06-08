#!/usr/bin/env bash
# Recipe: stand up a support bot with knowledge base + memory in one command.
# Usage: bash recipe_support_bot.sh <kb_name> <doc_file> [agent_name]
# Creates a KB, ingests the doc, and creates an agent wired to it (KNOWLEDGE_BASE + MEMORY).
# Prints the agent_id. Requires LYZR_API_KEY. Does NOT delete anything (it's a real build).
set -euo pipefail
KB_NAME="${1:?usage: recipe_support_bot.sh <kb_name> <doc_file> [agent_name]}"
DOC="${2:?need a document file (txt/pdf/docx)}"
AGENT_NAME="${3:-Support Bot}"
HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/lyzr.py"
AGENT="https://agent-prod.studio.lyzr.ai"; RAG="https://rag-prod.studio.lyzr.ai"
U="${LYZR_USER_ID:-cli@lyzr.ai}"
: "${LYZR_API_KEY:?set LYZR_API_KEY (see SETUP.md)}"

ext="${DOC##*.}"; case "$ext" in pdf) kind=pdf;; docx) kind=docx;; *) kind=txt;; esac

echo "1/3 creating KB '$KB_NAME'..."
RID=$(python3 "$S" rag-create "$KB_NAME" --user "$U" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")
echo "    rag_id=$RID"
echo "2/3 ingesting $DOC ($kind)..."
python3 "$S" rag-train "$RID" "$DOC" --kind "$kind" >/dev/null
echo "3/3 creating agent..."
AID=$(curl -s -X POST "$AGENT/v3/agents/" -H "x-api-key: $LYZR_API_KEY" -H "Content-Type: application/json" -d "{
  \"name\":\"$AGENT_NAME\",\"description\":\"Support bot with KB + memory.\",
  \"agent_role\":\"A helpful support agent.\",
  \"agent_instructions\":\"Answer using the knowledge base. If the answer is not there, say you don't know.\",
  \"agent_goal\":\"Resolve user questions from the KB.\",
  \"features\":[
    {\"type\":\"MEMORY\",\"config\":{\"max_messages_context_count\":20},\"priority\":0},
    {\"type\":\"KNOWLEDGE_BASE\",\"config\":{\"lyzr_rag\":{\"base_url\":\"$RAG\",\"rag_id\":\"$RID\",\"rag_name\":\"$KB_NAME\",\"params\":{\"top_k\":5,\"retrieval_type\":\"basic\",\"score_threshold\":0}},\"agentic_rag\":[]},\"priority\":0}
  ],
  \"llm_credential_id\":\"lyzr_anthropic\",\"provider_id\":\"Anthropic\",\"model\":\"claude-sonnet-4-6\",\"top_p\":0.95,\"temperature\":0.2}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['agent_id'])")

echo ""
echo "✅ Support bot ready."
echo "   rag_id   = $RID"
echo "   agent_id = $AID"
echo "   try: python3 $S chat $AID \"your question\""
