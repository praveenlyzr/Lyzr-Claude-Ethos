#!/usr/bin/env python3
"""Execute a Lyzr workflow (DAG) via the real run-dag engine and poll for results.

The /v3/workflows/{id}/execute endpoint is a STUB ("Workflow execution placeholder").
Real execution happens on the orchestration host:
  POST  https://lao.studio.lyzr.ai/run-dag/           body = bare flow_data  -> {status, task_id}
  GET   https://lao.studio.lyzr.ai/task-status/{id}   -> {status, results:{node_name: output}}

Usage:
  run_workflow.py <flow.json> [--inputs '{"user input":"..."}'] [--timeout 150]
  # <flow.json> is a flow_data object: {flow_name, run_name, default_inputs, tasks, edges}
  # If --inputs is given, its keys overwrite default_inputs for this run.

Requires LYZR_API_KEY. See reference/workflows.md for the node/data-flow contract.
"""
import argparse, json, os, sys, time, urllib.request, urllib.error

LAO = os.environ.get("LYZR_LAO_URL", "https://lao.studio.lyzr.ai")


def key():
    k = os.environ.get("LYZR_API_KEY")
    if not k:
        sys.exit("LYZR_API_KEY not set (see SETUP.md)")
    return k


def http(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("x-api-key", key())
    if data:
        r.add_header("Content-Type", "application/json")
    try:
        return json.loads(urllib.request.urlopen(r, timeout=90).read())
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')[:400]}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("flow", help="path to a flow_data JSON file")
    p.add_argument("--inputs", help="JSON object merged into default_inputs for this run")
    p.add_argument("--timeout", type=int, default=150, help="max seconds to poll")
    a = p.parse_args()

    flow = json.load(open(a.flow))
    if a.inputs:
        flow.setdefault("default_inputs", {}).update(json.loads(a.inputs))

    started = http("POST", f"{LAO}/run-dag/", flow)
    tid = started.get("task_id")
    if not tid:
        sys.exit(f"run-dag did not return a task_id: {started}")
    print(f"task_id={tid}  (polling up to {a.timeout}s)", file=sys.stderr)

    deadline = a.timeout
    waited = 0
    while waited < deadline:
        time.sleep(4)
        waited += 4
        s = http("GET", f"{LAO}/task-status/{tid}")
        st = s.get("status")
        if st not in ("processing", "pending", "running", None):
            res = s.get("results", {})
            print(f"status={st}  nodes={list(res.keys())}", file=sys.stderr)
            print(json.dumps(s, indent=2, ensure_ascii=False))
            return
        print(f"  ...{st} ({waited}s)", file=sys.stderr)
    sys.exit("timed out waiting for completion")


if __name__ == "__main__":
    main()
