# SuperFlow — durable visual workflows

Doc-derived. SuperFlow is Lyzr's drag-and-drop automation engine — distinct from the
Studio Workflow Builder ([`workflows.md`](workflows.md)): its differentiator is **durable,
exactly-once execution** (every step journaled; completed steps never re-run after a crash;
paused/approval waits consume no resources; cron uses durable timers).

Use it when you need branching, loops, human approval mid-flow, scheduling, or multi-agent
orchestration that must survive restarts.

## Nodes (each workflow has exactly one Trigger)
| Node | Purpose |
|------|---------|
| Trigger | Entry point + input shape; run via manual / webhook / schedule |
| AI Agent | Run a saved Lyzr agent (full config) |
| LLM | Inline model call; can use downstream nodes as tools in a reasoning loop |
| HTTP Request | External API (GET/POST/PUT/PATCH/DELETE, templated headers/body) |
| Code | JavaScript transform (last expression is the output; no `return`) |
| If / Switch | Conditional routing (rule-based or AI-evaluated) |
| Set / Merge / Sort / Filter | Reshape data |
| Loop | Iterate items individually or in batches |
| Wait for Approval | Durable human-approval pause (Output 0 approve / Output 1 reject) |
| Execute Workflow | Call another SuperFlow as a sub-step |

Also: DateTime, Crypto, XML, Parse, Extraction, AI Swarm, Tool, Label.

## Expressions (`{{ }}`)
Each node outputs a list of JSON objects; the next node receives it.
```
{{ $json }}                         # whole current input item
{{ $json.field }} / {{ $json.user.email }}
{{ $('Trigger').json.question }}    # reference another node by name
{{ $json.score > 0.8 ? 'high' : 'low' }}   # JS supported
Hello {{ $('Trigger').json.name }}  # interpolation in literals
```

## Triggers
- **Manual:** Run button (text or JSON input).
- **Webhook:** `POST <webhook-url>` with header `X-Webhook-Secret: <secret>`.
- **Schedule:** visual cron builder (hourly/daily/weekly/monthly/custom 5-field cron) with
  timezone; durable timers "never miss a tick".

## Running / reliability
- Live canvas status (amber=running, green=done, red=error, blue=awaiting approval).
- Durable controls: Pause / Resume / Terminate (survive restarts).
- Per-node "Retry on failure" with max attempts + backoff.
- History drawer: Executions + Approvals tabs; replay past runs / retry failed segments.
- Journaled: LLM calls, tools, HTTP, code, loop iterations, sub-workflows, approvals, schedules.
- Share with team (view/edit/execute; ownership retained).
