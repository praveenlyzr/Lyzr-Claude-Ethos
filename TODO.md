# TODO (internal)

Working notes for this repo / the `lyzr-agents` skill. Not part of the published skill content.

- [ ] **Agent-creation best practices + prompt patterns → fold into the skill.**
  Research/curate the best ways to design Lyzr agents and write effective `agent_role` /
  `agent_instructions` / `agent_goal` prompts (incl. structured-output and RAG-grounded
  patterns). Then add a `reference/prompting-and-best-practices.md` (and link it from
  `SKILL.md`) with concrete, reusable templates.

- [ ] **Promote/move this into the Lyzr core repository.**
  Decide whether to move or mirror the skill+plugin into the Lyzr core repo (e.g. `LyzrCore`)
  so it ships/maintained alongside the product, vs. keeping it as the standalone
  `praveenlyzr/Lyzr-Claude-Ethos` marketplace. If moving: update plugin/marketplace `source`,
  `repository`/`homepage` URLs, and install instructions accordingly.
