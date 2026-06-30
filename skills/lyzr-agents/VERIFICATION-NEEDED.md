# Verification needed — claims we have NOT confirmed with real data

Everything here is documented in the skill from **inference, a single pasted example, or the docs**,
but was **never confirmed by running it or seeing a real artifact**. If you can supply the data /
access in each "What would confirm it" line, I'll verify and tighten (or fix) the skill.

Legend: 🔴 likely-load-bearing (a wrong guess breaks a flow) · 🟡 plausible but unconfirmed · 🟢 nice-to-have.

---

## 1. SuperFlow execution — never run programmatically  🔴
There's no public SuperFlow **execution** API we found, so no SuperFlow in this skill has been run
end-to-end by us — only the underlying HTTP endpoints were tested (via curl, while they were live).
- `examples/.../superflow-order-automation.json` — backend data path tested; the **flow itself
  (LLM "Reorder Planner" + switch + http nodes) was never executed**.
- `examples/.../superflow-insurance-filing.json` — **never executed at all**; only structurally validated.
- `examples/superflow-crypto-copilot.json` — built/iterated against your manual imports, but we never
  drove a run via API.
- **What would confirm it:** import each into Studio → SuperFlow, **Run**, and send me (a) does it
  import without crashing, (b) the run output or any node error. Even a screenshot/JSON of a failed
  node helps. Or: point me at a SuperFlow run/execute API endpoint if one exists.

## 2. New node JSON shapes — documented from your ONE pasted flow, not a verified export  🔴
The insurance flow introduced nodes I added to `reference/superflow.md` based only on the JSON you
pasted (+ n8n analogy). I have **not** seen a real Studio export of these, nor run them:
- `lyzr-nodes-base.merge` — `mode:"append"`, multi-input **barrier**, and the assumption that after it
  `$input.all()` is the concatenation of both branches' items.
- `lyzr-nodes-base.waitForApproval` — that `main[0]=approve / main[1]=reject`, the `formSchema` shape,
  and **critically** that the submitted form fields (`actuary_remarks`/`rework_note`) get merged onto
  the item passed down AND that the upstream item passes through (Build Submission depends on both).
- `switch` **typeVersion 3** — the `operator:{operation:"equals"}` + `combineOperation:"and"` shape.
- **What would confirm it:** a **real Studio export** (Download/Export JSON) of any flow that uses
  merge, waitForApproval, and a v3 switch — so I can diff my documented shapes against ground truth.

## 3. `lyzr.llm` data behaviors — inferred, not verified  🔴
- **Pass-through:** that an LLM node passes its input through AND adds `output` (so downstream `$json`
  has both upstream fields and `output`). Inferred from the original author's flow; not directly tested.
- **`responseFormat` parsing:** whether `output` is a **parsed object** (`output.memo`) vs a **raw JSON
  string**. We switched the insurance flow to strict `json_schema` to be safe; the behavior of
  `{type:"json_object"}` is unconfirmed.
- **What would confirm it:** run any 2-node flow (LLM → Code that returns `$json`) and send me the Code
  node's input — does it show `output` as an object, and are the upstream fields still present?

## 4. `code` node (typeVersion 2) conventions — inferred from the pasted flow  🟡
- That an item's json **is** the object directly (`$input.first()` → object; `p.field`, not `p.json.field`).
- That a script ends with a **bare last-expression array** (`[ {...} ]`) and that's the output (no `return`).
- Whether `$('Other Node').json` / `.first()` works **inside a code node** (not just in `={{ }}` expressions).
- **What would confirm it:** one exported/run code node from your Studio, or a quick test result.

## 5. gitagent — fixed to spec, but never actually run  🔴
`examples/.../gitagent/` passes YAML + frontmatter validation against the open-gitagent reference repo,
but we **never completed an end-to-end run** (it needs a provider API key, and the endpoints it calls
are now torn down).
- Unconfirmed: that the agent loads cleanly past the two fixes, that `model.preferred:
  "anthropic:claude-sonnet-4-6"` resolves on **your** key (vs needing the OpenAI fallback), and that it
  actually curls the flow correctly.
- **What would confirm it:** redeploy the endpoints (`bash infra/deploy.sh customagents`), set
  `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY`), run `gitagent` with an order prompt, and paste the transcript.
  Also: which provider key do you intend to use, so I can set `preferred` accordingly?

## 6. Saving / managing a SuperFlow via API — never got it working  🟡
Early on you couldn't find a flow we tried to create on the Studio; we never confirmed a programmatic
**create/save** path for SuperFlows (only manual Import JSON in the UI).
- **What would confirm it:** confirmation of whether a SuperFlow create/save API exists (and its
  endpoint/payload), or that manual import is the only supported path.

## 7. SuperFlow node catalog is reverse-engineered (the docs 404'd)  🟡
The whole `reference/superflow.md` catalog was built from real exports you shared + live testing, but
the official SuperFlow `.md` docs returned 404 when we looked. So the catalog is "verified where we
tested, inferred elsewhere," not docs-backed.
- **What would confirm it:** a working link to official SuperFlow node docs, or a couple more real
  exports covering nodes we haven't seen (`splitInBatches` loop, `lyzr.tool` in a working flow, etc.).

---

### Quick "arrange for it" checklist (smallest set that unblocks the most)
1. **Export JSON of a real flow** using merge + waitForApproval + v3 switch → unblocks §2, §4, partially §3.
2. **Run both SuperFlows in Studio** and send import result + run output/errors → unblocks §1, §3.
3. **Which provider key for gitagent** (+ optionally a run transcript after a redeploy) → unblocks §5.
4. **Is there a SuperFlow create/run API?** (yes/no + endpoint) → unblocks §1, §6.
