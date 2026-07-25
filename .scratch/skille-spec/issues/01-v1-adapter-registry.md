# v1 adapter registry for Scan

Type: research
Status: resolved

## Question

What exact agent adapter registry should Skille ship in v1: for each adapter, which detect paths, which skill roots (user/global and project), install target defaults (including when to suggest `.agents/skills`), and what detection rule (agent install present vs skill root present vs `SKILL.md` content)? Produce a cited registry table suitable to paste into the product spec, bootstrapped from vendor docs and cross-checked against `vercel-labs/skills` — without treating the CLI table as authoritative over vendor docs.

Prefer building on [`.scratch/research/agent-skill-discovery-and-existing-tools.md`](../../research/agent-skill-discovery-and-existing-tools.md); deepen where that note left gaps (Codex path split, Cursor dual roots, detection heuristic choice).

## Answer

Ship a **vendor-verified, extensible** registry of eight adapters (Cursor, Claude Code, Codex, Gemini CLI, OpenCode, Goose, GitHub Copilot/VS Code, Amp) — Scan discovers which apply; not a 3-agent whitelist and not the full `npx skills` table.

- **Detect adapters:** agent install/config path present, or (secondary) any of that adapter’s skill roots present.
- **List skills:** walk in-scope roots for directories containing `SKILL.md` (content layer only; do not invent adapter identity from `SKILL.md` alone).
- **Install default:** suggest `.agents/skills` / `~/.agents/skills` when the vendor loads that convention; else the native root. Codex: scan deprecated `$CODEX_HOME/skills` but never default-install there. Cursor: register both `.agents` and `.cursor` pairs; default `.agents`; treat Claude/Codex paths as foreign compat roots.

Full cited registry table, policies, and CLI cross-check: [`.scratch/research/v1-adapter-registry.md`](../../research/v1-adapter-registry.md).
