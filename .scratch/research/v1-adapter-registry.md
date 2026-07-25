# v1 adapter registry for Scan

**Summary.** Skille v1 should ship a **vendor-verified** adapter registry (not a 3-agent whitelist, and not the full ~70-row `vercel-labs/skills` table). Detect adapters by **agent install/config presence** (with skill-root existence as a secondary signal). Discover skill **content** by walking registered skill roots for directories containing `SKILL.md`. Default install suggestion is **`.agents/skills` / `~/.agents/skills` when the vendor loads that convention**; otherwise the vendor-native root. Prefer vendor docs over the CLI table when they disagree — notably Codex (CLI still writes `$CODEX_HOME/skills` globally) and Cursor (CLI global target is `~/.cursor/skills` while docs also load `~/.agents/skills`).

Builds on [agent-skill-discovery-and-existing-tools.md](./agent-skill-discovery-and-existing-tools.md). Research date: 2026-07-25.

---

## 1. Recommended detection rule

Use **two layers**. Do not collapse “agent present,” “skill root present,” and “skill content” into one boolean.

| Layer | Purpose | Rule |
|-------|---------|------|
| **A. Adapter presence** | Which agents appear in Scan / Install target pickers | **Primary:** any `detect` path exists (home/config/app marker for that product). **Secondary:** any of that adapter’s skill roots exists even if the home marker is missing (covers partial installs / migrated trees). |
| **B. Skill content** | What appears in the Library | Under each **in-scope** skill root (globals always; project roots only for user-added Projects), discover skill packages as directories containing a file named exactly `SKILL.md` ([agentskills.io adding-skills-support](https://agentskills.io/client-implementation/adding-skills-support); [spec](https://agentskills.io/specification)). |

**Do not** use `SKILL.md` alone to invent an adapter identity. Shared roots (especially `~/.agents/skills`) are loaded by multiple clients; attribute content to the **skill root**, then note which detected adapters **also load** that root.

**Why not skill-root-only for adapter detection?** An installed agent with empty skill dirs should still appear as an Install target (same pattern as `vercel-labs/skills` `detectInstalled` on home dirs — [agents.ts](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts)).

**Why not SKILL.md-only for adapter detection?** Skills under `.agents/skills` do not identify which agent “owns” them; the open convention is explicitly cross-client ([adding-skills-support](https://agentskills.io/client-implementation/adding-skills-support)).

**Scope reminder (product):** Library defaults to user/global skill roots; project skill roots join only when the user adds a Project — no full-disk crawl (`CONTEXT.md`).

---

## 2. Install default policy

1. **If the adapter’s vendor docs load `.agents/skills` and/or `~/.agents/skills`:** preselect that pair (project vs user matching the Install scope). This is the ecosystem interoperability path ([agentskills.io](https://agentskills.io/client-implementation/adding-skills-support)), not an app vault.
2. **Else:** preselect the vendor-native project/user skill root from the registry.
3. **Always allow multi-select** of additional roots the adapter (or other selected adapters) load — copy into each chosen root (product Install model).
4. **Never default-install into deprecated or compatibility-only roots** when a preferred root exists (Codex: do not default to `$CODEX_HOME/skills`; Cursor: do not prefer Claude/Codex compat roots as Cursor install targets).
5. **Shared `.agents` skills** written once remain visible to every detected adapter that loads that convention — one copy, many readers.

---

## 3. Spec-ready registry table (v1 ship set)

Paths use `~` for the user home. On macOS, honor `$XDG_CONFIG_HOME` when set; otherwise `~/.config` for XDG-style entries (same approach as [vercel-labs/skills `agents.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts)). `$CODEX_HOME` defaults to `~/.codex` when unset ([Codex loader](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs)). `$CLAUDE_CONFIG_DIR` may relocate Claude’s home (CLI table acknowledges this; Claude docs use `~/.claude` as the documented personal path).

| Adapter | Detect paths (presence) | Skill roots — user/global | Skill roots — project | Default install (suggest) | Also loads (scan for content; not default install for this adapter) | Authority |
|---------|-------------------------|---------------------------|-----------------------|---------------------------|---------------------------------------------------------------------|-----------|
| **Cursor** | `~/.cursor` | `~/.agents/skills/`, `~/.cursor/skills/` | `.agents/skills/`, `.cursor/skills/` (incl. nested project dirs per docs) | **`.agents/skills/`** / **`~/.agents/skills/`**; offer `.cursor/skills` / `~/.cursor/skills` as native alternate | Compatibility load: `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/` | [cursor.com/docs/skills](https://cursor.com/docs/skills) |
| **Claude Code** | `~/.claude` (or `$CLAUDE_CONFIG_DIR`) | `~/.claude/skills/` | `.claude/skills/` (parent walk to repo root; nested package skills) | **`.claude/skills/`** / **`~/.claude/skills/`** (no `.agents` in vendor docs) | Plugin / enterprise managed locations (out of v1 install defaults; discover later if needed) | [code.claude.com/docs/en/skills.md](https://code.claude.com/docs/en/skills.md) |
| **Codex** | `~/.codex` or `$CODEX_HOME`; `/etc/codex` (admin marker) | **Preferred:** `$HOME/.agents/skills`. **Still loaded (deprecated):** `$CODEX_HOME/skills` (not `.system` bundle). **Admin:** `/etc/codex/skills` | `.agents/skills` on CWD and every ancestor up to repo root | **`.agents/skills`** / **`$HOME/.agents/skills`** only | Deprecated `$CODEX_HOME/skills` for Scan/Library completeness; do not suggest for new Install. System bundle under `$CODEX_HOME/skills/.system` is OpenAI-bundled — list if visible, never install target | Docs: [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills) (`Where Codex loads local skills`). Source: [loader.rs](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs) |
| **Gemini CLI** | `~/.gemini` | `~/.agents/skills/` (alias, **precedence** within user tier), `~/.gemini/skills/` | `.agents/skills/` (alias, precedence), `.gemini/skills/` | **`.agents/skills/`** / **`~/.agents/skills/`** | Native `.gemini` / `~/.gemini` as alternate | [geminicli.com/docs/cli/skills](https://geminicli.com/docs/cli/skills/) |
| **OpenCode** | `~/.config/opencode` (XDG) | `~/.agents/skills/`, `~/.config/opencode/skills/`, `~/.claude/skills/` | `.agents/skills/`, `.opencode/skills/`, `.claude/skills/` (walk to git worktree) | **`.agents/skills/`** / **`~/.agents/skills/`**; offer `.opencode/skills` / `~/.config/opencode/skills` as native | Claude-compatible roots | [opencode.ai/docs/skills](https://opencode.ai/docs/skills/) |
| **Goose** | `~/.config/goose` (XDG) — CLI table; docs emphasize skill paths | **Recommended:** `~/.agents/skills/`; also `~/.claude/skills/` + platform config dirs (legacy) | **Recommended:** `.agents/skills/`; also `.goose/skills/`, `.claude/skills/` | **`.agents/skills/`** / **`~/.agents/skills/`** | Legacy `.goose/skills`, Claude paths | [goose using-skills.md](https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/docs/guides/context-engineering/using-skills.md) |
| **GitHub Copilot** (incl. VS Code agent skills) | `~/.copilot` | `~/.copilot/skills`, `~/.agents/skills` (VS Code also documents `~/.claude/skills`) | `.github/skills`, `.agents/skills`, `.claude/skills` | **`.agents/skills`** / **`~/.agents/skills`**; offer `.github/skills` / `~/.copilot/skills` as native | Claude-compatible roots | [About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills); [VS Code agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) |
| **Amp** | `~/.config/amp` (XDG) | Precedence (first wins): `~/.config/agents/skills/`, `~/.agents/skills/`, `~/.config/amp/skills/`, plus `~/.claude/skills/` | `.agents/skills/`, `.claude/skills/` | **`.agents/skills/`** / **`~/.agents/skills/`** (or `~/.config/agents/skills` if matching Amp’s highest user precedence) | Claude paths; Amp-specific `~/.config/amp/skills` | [ampcode.com/manual/agent-skills.md](https://ampcode.com/manual/agent-skills.md) |

### Shared root (not an adapter)

| Root | Role | Scan | Install |
|------|------|------|---------|
| `~/.agents/skills`, `.agents/skills` | Cross-client convention ([agentskills.io](https://agentskills.io/client-implementation/adding-skills-support)) | Always include in global/project skill walks when present / when Project added | Default suggestion whenever a **selected** adapter supports it |

### Explicitly out of v1 ship set (bootstrap only)

The [vercel-labs/skills `agents` map](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts) lists many more agents (Antigravity, Cline, Roo, Windsurf-adjacent paths, etc.). Treat that file as a **bootstrap checklist**, not authority. Add an adapter to Skille only after a **first-party** doc or source path is verified. Until then, skills found only under unknown vendor dirs are invisible unless the user adds a Project that happens to contain a registered project root pattern — do not invent adapters from CLI rows alone.

---

## 4. Gap deep-dives (from prior research)

### 4.1 Codex path split

| Claim | Source |
|-------|--------|
| Documented local scopes for authoring/discovery are `REPO` → `.agents/skills` (ancestor walk), `USER` → `$HOME/.agents/skills`, `ADMIN` → `/etc/codex/skills`, `SYSTEM` → bundled | [Codex skills docs — Where Codex loads local skills](https://developers.openai.com/codex/skills) |
| Source still registers **deprecated** user root `$CODEX_HOME/skills` for backward compatibility, **and** `$HOME/.agents/skills` | [loader.rs](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs) comments at User layer |
| `vercel-labs/skills` sets Codex `skillsDir: '.agents/skills'` but `globalSkillsDir: join(codexHome, 'skills')` | [agents.ts](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts) — **lags preferred user path** |

**Skille decision:** Scan **both** preferred and deprecated user roots; Install/Author **only** preferred `.agents` paths; detect via `$CODEX_HOME` / `~/.codex` (and `/etc/codex` for admin awareness).

### 4.2 Cursor dual roots

| Claim | Source |
|-------|--------|
| Official project roots: `.agents/skills/`, `.cursor/skills/` | [Cursor Skills](https://cursor.com/docs/skills) |
| Official user roots: `~/.agents/skills/`, `~/.cursor/skills/` | same |
| Also loads Claude + Codex skill dirs for compatibility | same |
| `vercel-labs/skills` installs Cursor project → `.agents/skills`, global → `~/.cursor/skills` | [agents.ts](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts) — **asymmetric**; not wrong for project, but global should prefer `~/.agents/skills` per product constraint + docs |

**Skille decision:** Register **both** native pairs. Default suggest `.agents` (project + user). Keep `.cursor/skills` selectable. Treat Claude/Codex paths as **foreign roots Cursor can see**, owned by Claude/Codex adapters for Install defaults — avoid double-copy into compat paths unless the user explicitly multi-selects them.

### 4.3 Detection heuristic choice

| Heuristic | Pros | Cons | Verdict for Skille |
|-----------|------|------|--------------------|
| Agent install/config present | Matches `npx skills` / Skills Manager; empty agents still Install-ready | May false-positive leftover config dirs | **Primary** |
| Skill root present | Catches skills without clean “app home” | Misses empty fresh installs; `.agents` is multi-agent | **Secondary** for presence |
| `SKILL.md` content | True Library inventory | Cannot name the adapter; expensive if used as sole presence check | **Content layer only** |

---

## 5. Cross-check vs `vercel-labs/skills` (non-authoritative)

| Adapter | CLI detect (agents.ts) | CLI skillsDir / globalSkillsDir | Vendor vs CLI |
|---------|------------------------|----------------------------------|---------------|
| Cursor | `~/.cursor` | `.agents/skills` / `~/.cursor/skills` | Detect OK. Global install target should prefer `~/.agents/skills` per Cursor docs + Skille policy. |
| Claude Code | `$CLAUDE_CONFIG_DIR` or `~/.claude` | `.claude/skills` / `…/skills` | Aligned with Claude docs. |
| Codex | `$CODEX_HOME` or `~/.codex`, `/etc/codex` | `.agents/skills` / `$CODEX_HOME/skills` | Detect OK. **Global target outdated** vs docs/source preferred `$HOME/.agents/skills`. |
| Gemini CLI | `~/.gemini` | `.agents/skills` / `~/.gemini/skills` | Aligned; docs also alias `~/.agents/skills` with precedence. |
| OpenCode | `~/.config/opencode` | `.agents/skills` / `~/.config/opencode/skills` | Aligned; docs also list Claude + agents globals. |
| Goose | `~/.config/goose` | `.goose/skills` / `~/.config/goose/skills` | **CLI native paths are legacy-leaning**; Goose docs recommend `.agents/skills` / `~/.agents/skills`. Prefer docs for defaults; still scan `.goose/skills` if present. |
| GitHub Copilot | `~/.copilot` | `.agents/skills` / `~/.copilot/skills` | Aligned with GitHub docs; project also has `.github/skills`. |
| Amp | `~/.config/amp` | `.agents/skills` / `~/.config/agents/skills` | Aligned with Amp manual (`.agents` project; user precedence includes `~/.config/agents/skills` and `~/.agents/skills`). |

---

## 6. Paste-ready product rules (short)

1. **Registry:** ship the eight adapters in §3, data-driven and extensible; Scan discovers which apply — no fixed “Cursor/Claude/Codex only” product whitelist.
2. **Detect:** install/config path **or** skill-root existence (§1 layer A).
3. **List skills:** `SKILL.md` packages under in-scope roots (§1 layer B).
4. **Install default:** `.agents/skills` / `~/.agents/skills` when supported; else native root (§2).
5. **Authority order:** vendor docs/source → then ecosystem CLI table for bootstrap ideas only.

---

## Sources (primary)

- Agent Skills convention: https://agentskills.io/client-implementation/adding-skills-support · https://agentskills.io/specification
- Cursor: https://cursor.com/docs/skills
- Claude Code: https://code.claude.com/docs/en/skills.md
- Codex docs: https://developers.openai.com/codex/skills · Codex source: https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs
- Gemini CLI: https://geminicli.com/docs/cli/skills/
- OpenCode: https://opencode.ai/docs/skills/
- Goose: https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/docs/guides/context-engineering/using-skills.md
- GitHub Copilot: https://docs.github.com/en/copilot/concepts/agents/about-agent-skills
- VS Code: https://code.visualstudio.com/docs/agent-customization/agent-skills
- Amp: https://ampcode.com/manual/agent-skills.md
- Cross-check only: https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts
- Prior note: [agent-skill-discovery-and-existing-tools.md](./agent-skill-discovery-and-existing-tools.md)
