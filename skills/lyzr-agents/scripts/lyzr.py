#!/usr/bin/env python3
"""Lyzr Agent Studio API helper CLI.

Wraps the verified /v3 agent endpoints. Reads the key from $LYZR_API_KEY.

Usage:
  lyzr.py list
  lyzr.py get <agent_id>
  lyzr.py create --file agent.json
  lyzr.py update <agent_id> --file agent.json
  lyzr.py delete <agent_id>
  lyzr.py chat <agent_id> "message" [--session S] [--user U] [--stream]
  lyzr.py models

agent.json is a JSON object with at least: name, agent_role, agent_instructions,
llm_credential_id, provider_id, model. See SKILL.md for the full field list.
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
import urllib.parse

BASE = os.environ.get("LYZR_BASE_URL", "https://agent-prod.studio.lyzr.ai")
RAG_BASE = os.environ.get("LYZR_RAG_URL", "https://rag-prod.studio.lyzr.ai")
RAI_BASE = os.environ.get("LYZR_RAI_URL", "https://rai-prod.studio.lyzr.ai")
VOICE_BASE = os.environ.get("LYZR_VOICE_URL", "https://voice-livekit.studio.lyzr.ai")

KNOWN_MODELS = [
    ("Anthropic", "claude-sonnet-4-6", "lyzr_anthropic"),
    ("OpenAI", "gpt-4.1", "lyzr_openai"),
    ("OpenAI", "gpt-4o", "lyzr_openai"),
    ("OpenAI", "gpt-4o-mini", "lyzr_openai"),
    ("OpenAI", "gpt-5", "lyzr_openai"),
    ("OpenAI", "o3", "lyzr_openai"),
    ("OpenAI", "gpt-5-nano", "lyzr-default"),
    ("Google", "gemini-2.0-flash", "lyzr_google"),
    ("Google", "gemini/gemini-3.1-flash-lite", "lyzr_google"),
]


def key():
    k = os.environ.get("LYZR_API_KEY")
    if not k:
        sys.exit("LYZR_API_KEY not set. Run: source ~/.zshrc")
    return k


def req(method, path, body=None, stream=False, base=None):
    url = (base or BASE) + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("x-api-key", key())
    if data:
        r.add_header("Content-Type", "application/json")
    try:
        resp = urllib.request.urlopen(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')}")
    if stream:
        for line in resp:
            sys.stdout.write(line.decode(errors="replace"))
            sys.stdout.flush()
        return None
    raw = resp.read().decode()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def pp(obj):
    print(json.dumps(obj, indent=2, ensure_ascii=False))


def main():
    p = argparse.ArgumentParser(description="Lyzr Agent Studio API helper")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list")
    g = sub.add_parser("get"); g.add_argument("agent_id")
    c = sub.add_parser("create"); c.add_argument("--file", required=True)
    u = sub.add_parser("update"); u.add_argument("agent_id"); u.add_argument("--file", required=True)
    d = sub.add_parser("delete"); d.add_argument("agent_id")
    ch = sub.add_parser("chat")
    ch.add_argument("agent_id"); ch.add_argument("message")
    ch.add_argument("--session", default="cli-session")
    ch.add_argument("--user", default=os.environ.get("LYZR_USER_ID", "cli@lyzr.ai"))
    ch.add_argument("--stream", action="store_true")
    sub.add_parser("models")

    # versions / sessions (read)
    v = sub.add_parser("versions"); v.add_argument("agent_id")
    se = sub.add_parser("sessions"); se.add_argument("agent_id")
    hi = sub.add_parser("history"); hi.add_argument("session_id")
    hi.add_argument("--agent", help="scope history to an agent_id")

    # rag
    rl = sub.add_parser("rag-list"); rl.add_argument("--user", default=os.environ.get("LYZR_USER_ID", "cli@lyzr.ai"))
    rg = sub.add_parser("rag-get"); rg.add_argument("rag_id")
    rr = sub.add_parser("rag-retrieve")
    rr.add_argument("rag_id"); rr.add_argument("query")
    rr.add_argument("--top-k", type=int, default=5)
    rr.add_argument("--type", default="basic", choices=["basic", "mmr", "hyde", "time_aware"])
    rc = sub.add_parser("rag-create")
    rc.add_argument("collection_name")
    rc.add_argument("--user", default=os.environ.get("LYZR_USER_ID", "cli@lyzr.ai"))
    rc.add_argument("--description", default="Created via lyzr.py")
    rt = sub.add_parser("rag-train")
    rt.add_argument("rag_id"); rt.add_argument("file")
    rt.add_argument("--kind", default="txt", choices=["txt", "pdf", "docx"])
    rrs = sub.add_parser("rag-reset"); rrs.add_argument("rag_id")
    rd = sub.add_parser("rag-delete"); rd.add_argument("rag_id")

    # workflows
    sub.add_parser("workflows")
    wg = sub.add_parser("workflow-get"); wg.add_argument("flow_id")
    wd = sub.add_parser("workflow-delete"); wd.add_argument("flow_id")

    # tools / voice listings (verified)
    sub.add_parser("ready-tools")                 # ready-made (aci/Composio) tool catalog
    td2 = sub.add_parser("tool-delete"); td2.add_argument("tool_id")
    sub.add_parser("voice-list")                  # voice agents
    sub.add_parser("rai-policies")                # list RAI policies

    # responsible AI checks
    pi = sub.add_parser("rai-injection"); pi.add_argument("text"); pi.add_argument("--agent", default="cli"); pi.add_argument("--session", default="rai")
    tx = sub.add_parser("rai-toxicity"); tx.add_argument("text"); tx.add_argument("--agent", default="cli"); tx.add_argument("--session", default="rai")

    # docs fallback: fetch any doc page as raw markdown (no auth)
    dc = sub.add_parser("docs"); dc.add_argument("page", help="doc path, full URL, or 'index'")

    a = p.parse_args()

    if a.cmd == "list":
        agents = req("GET", "/v3/agents/")
        for ag in agents:
            print(f"{ag.get('_id')}  {ag.get('name')}  [{ag.get('provider_id')}/{ag.get('model')}]")
        print(f"\n{len(agents)} agents", file=sys.stderr)
    elif a.cmd == "get":
        pp(req("GET", f"/v3/agents/{a.agent_id}"))
    elif a.cmd == "create":
        body = json.load(open(a.file))
        pp(req("POST", "/v3/agents/", body))
    elif a.cmd == "update":
        body = json.load(open(a.file))
        pp(req("PUT", f"/v3/agents/{a.agent_id}", body))
    elif a.cmd == "delete":
        pp(req("DELETE", f"/v3/agents/{a.agent_id}"))
    elif a.cmd == "chat":
        body = {"user_id": a.user, "agent_id": a.agent_id,
                "session_id": a.session, "message": a.message}
        if a.stream:
            req("POST", "/v3/inference/stream/", body, stream=True)
        else:
            out = req("POST", "/v3/inference/chat/", body)
            print(out.get("response", out) if isinstance(out, dict) else out)
    elif a.cmd == "models":
        print(f"{'provider_id':12} {'model':32} llm_credential_id")
        for prov, model, cred in KNOWN_MODELS:
            print(f"{prov:12} {model:32} {cred}")
    elif a.cmd == "versions":
        pp(req("GET", f"/v3/agents/{a.agent_id}/versions"))
    elif a.cmd == "sessions":
        pp(req("GET", f"/v1/agent/{a.agent_id}/sessions"))
    elif a.cmd == "history":
        path = (f"/v1/sessions/{a.session_id}/{a.agent}/history" if a.agent
                else f"/v1/sessions/{a.session_id}/history")
        pp(req("GET", path))
    elif a.cmd == "rag-list":
        pp(req("GET", f"/v3/rag/user/{a.user}/", base=RAG_BASE))
    elif a.cmd == "rag-get":
        pp(req("GET", f"/v3/rag/{a.rag_id}/", base=RAG_BASE))
    elif a.cmd == "rag-create":
        body = {
            "user_id": a.user,
            "llm_credential_id": "lyzr_openai",
            "embedding_credential_id": "lyzr_openai",
            "vector_db_credential_id": "lyzr_qdrant",
            "vector_store_provider": "Qdrant [Lyzr]",
            "collection_name": a.collection_name,
            "llm_model": "gpt-4o-mini",
            "embedding_model": "text-embedding-ada-002",
            "description": a.description,
            "semantic_data_model": False,
            "meta_data": {},
        }
        pp(req("POST", "/v3/rag/", body, base=RAG_BASE))
    elif a.cmd == "rag-train":
        # multipart upload via urllib (no requests dependency)
        import mimetypes, uuid
        boundary = "----lyzr" + uuid.uuid4().hex
        fname = os.path.basename(a.file)
        ctype = mimetypes.guess_type(fname)[0] or "application/octet-stream"
        with open(a.file, "rb") as fh:
            payload = fh.read()
        body = (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{fname}\"\r\nContent-Type: {ctype}\r\n\r\n"
        ).encode() + payload + f"\r\n--{boundary}--\r\n".encode()
        url = f"{RAG_BASE}/v3/train/{a.kind}/?rag_id={a.rag_id}"
        r = urllib.request.Request(url, data=body, method="POST")
        r.add_header("x-api-key", key())
        r.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        try:
            print(urllib.request.urlopen(r).read().decode())
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')}")
    elif a.cmd == "rag-reset":
        pp(req("DELETE", f"/v3/rag/{a.rag_id}/reset/", base=RAG_BASE))
    elif a.cmd == "rag-delete":
        pp(req("DELETE", f"/v3/rag/{a.rag_id}/", base=RAG_BASE))
    elif a.cmd == "rag-retrieve":
        from urllib.parse import quote
        q = (f"/v3/rag/{a.rag_id}/retrieve/?query={quote(a.query)}&top_k={a.top_k}"
             f"&retrieval_type={a.type}&score_threshold=0.0&lambda_param=0.5&time_decay_factor=0.0")
        pp(req("GET", q, base=RAG_BASE))
    elif a.cmd == "workflows":
        pp(req("GET", "/v3/workflows/"))
    elif a.cmd == "workflow-get":
        pp(req("GET", f"/v3/workflows/{a.flow_id}"))
    elif a.cmd == "workflow-delete":
        print(req("DELETE", f"/v3/workflows/{a.flow_id}") or "deleted (204)")
    elif a.cmd == "ready-tools":
        cat = req("GET", "/v3/providers/tools/all")
        for t in (cat if isinstance(cat, list) else []):
            print(f"{t.get('provider_id','?'):24} {t.get('_id','')}")
        print(f"\n{len(cat) if isinstance(cat,list) else 0} ready tools", file=sys.stderr)
    elif a.cmd == "tool-delete":
        pp(req("DELETE", f"/v3/tools/{a.tool_id}"))
    elif a.cmd == "voice-list":
        d = req("GET", "/v1/agents", base=VOICE_BASE)
        for ag in (d.get("agents", []) if isinstance(d, dict) else []):
            print(f"{ag.get('id')}  {ag.get('config',{}).get('agent_name','?')}")
    elif a.cmd == "rai-policies":
        d = req("GET", "/v1/rai/policies", base=RAI_BASE)
        for p in (d.get("policies", []) if isinstance(d, dict) else []):
            print(f"{p.get('_id')}  {p.get('name')}")
    elif a.cmd in ("rai-injection", "rai-toxicity"):
        path = "/prompt-injection-dectector/" if a.cmd == "rai-injection" else "/toxicity-meter/"
        body = {"input_text": a.text, "agent_id": a.agent, "session_id": a.session}
        pp(req("POST", path, body, base=RAI_BASE))
    elif a.cmd == "docs":
        # last-resort doc lookup: any Lyzr doc page is raw markdown at <url>.md (no auth)
        page = "llms.txt" if a.page == "index" else a.page
        if page.startswith("http"):
            url = page if page.endswith(".md") or page.endswith(".txt") else page + ".md"
        else:
            url = "https://docs.lyzr.ai/" + page.lstrip("/")
            if not (url.endswith(".md") or url.endswith(".txt")):
                url += ".md"
        url = urllib.parse.quote(url, safe=":/?&=.")
        try:
            r = urllib.request.Request(url, method="GET")
            print(urllib.request.urlopen(r).read().decode(errors="replace"))
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code} for {url} — check the path in reference/docs-index.md")


if __name__ == "__main__":
    main()
