# Agent skill discovery & existing control-layer tools

**Summary.** A shared **Agent Skills** package format (`SKILL.md` + optional `scripts/` / `references/` / `assets/`) is now an open standard at [agentskills.io](https://agentskills.io), originally from Anthropic and adopted by Cursor, Claude Code, OpenAI Codex/ChatGPT, Gemini CLI, OpenCode, Goose, GitHub Copilot/VS Code, Amp, and many others. **On-disk roots remain vendor-specific**, with `.agents/skills/` emerging as the cross-client interoperability path (spec does not mandate locations). Several open-source CLIs and one notable desktop app already install/sync/list skills across agents; the dominant installer is Vercel’s [`vercel-labs/skills`](https://github.com/vercel-labs/skills) (`npx skills`). Multiple tools **auto-detect installed agents by probing home/config directories**. Closest product overlap for a local “control layer” that overlays browse/edit/git-install without owning content is mixed: most managers invent a **canonical store** (library + symlink/copy out), which conflicts with a strict “agents’ roots are the store” constraint—except where installers write **directly into agent skill directories**.

---

## 1. What open-source / GitHub projects already help discover, list, install, sync, or manage local agent skills?

Verified against each project’s own README / source (not blog roundups):

### Ecosystem CLI / registry (highest signal)

| Project | Repo | What it actually does | Relevance |
|--------|------|----------------------|-----------|
| **skills** (`npx skills`) | https://github.com/vercel-labs/skills | Package-manager CLI for Agent Skills: `add` / `find` / `list` / `update` / `remove` / `init` / `use` from git (GitHub/GitLab/any git URL) or local paths; installs via **symlink or copy** into many agents’ project/global skill dirs; marketplace UI at https://skills.sh | **Primary existing installer.** Large ecosystem surface (~70 agents tabulated in README). Closest to “install from git URL into agent roots.” |
| **skills.sh** | https://skills.sh (directory UI; installs via `npx skills`) | Discovery/search front-end for the same ecosystem | Discovery UX, not a separate control-layer store. |
| **Agent Skills standard + skills-ref** | https://github.com/agentskills/agentskills · https://agentskills.io | Spec for `SKILL.md`; reference validator `skills-ref validate` (README marks skills-ref as **demo / not production**) | Format authority; not a multi-agent manager. |
| **anthropics/skills** | https://github.com/anthropics/skills | Official example / public skill collection | Content source, not a manager. |

### Multi-agent managers (direct overlap with a control layer)

| Project | Repo | What it actually does | Relevance |
|--------|------|----------------------|-----------|
| **Skills Manager** (desktop + CLI) | https://github.com/xingkongliang/skills-manager | Tauri desktop app: central library (default `~/.skills-manager`), install from git/local/zip/skills.sh, sync to 15+ agents via symlink/copy, **scan** agent dirs for unmanaged skills, presets, backup sync, custom tool paths | **Closest desktop analogue.** Strong scan/list/sync UX. **Invented canonical library** + SQLite metadata — conflicts with “no own content store” if taken as architecture. |
| **Leogriel** (formerly skillctl) | https://github.com/xFurti/leogriel (https://github.com/xFurti/skillctl → 301) | npm CLI `@leogriel/cli`: manifest/lockfile (`agent-skills.json` / `agent-skills.lock`), store under `.leogriel/skills` / `~/.leogriel/skills`, sync/symlink into agents; `import` from existing agent dirs; `doctor`, audit, experimental tests | Package-manager model with **own store**; `import` is useful for “scan what’s already on disk.” |
| **Skilled** | https://github.com/helincao/skilled | CLI: install/sync/upstream/check from GitHub into project; uses **`.agents/skills/` as canonical**, symlinks into vendor dirs (`.claude/skills`, etc.); lockfile `skills.lock.json`; auto-detect agents by project marker dirs | Multi-agent sync + drift; still a **project-local canonical tree** (+ lockfile). Very early (≈0 stars as of research date). |
| **agent-skill-manager** (`sm`) | https://github.com/ackness/skill-manager | Python CLI: download/discover from GitHub, deploy/list/update/uninstall across many agents; default download dest `~/.skill-manager/skills/`; symlink deploy | Install/deploy manager with **own download cache**. Low adoption. |

### First-party / vendor installers (not cross-agent control layers, but relevant)

| Project / product | Primary URL | What it does | Relevance |
|-------------------|-------------|--------------|-----------|
| **GitHub CLI `gh skill`** | https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills | Search / preview / install / update / publish skills into Copilot locations (preview; CLI ≥ 2.90.0) | Official install path for Copilot; not multi-agent. |
| **Gemini CLI `gemini skills`** | https://geminicli.com/docs/cli/skills/ | `list` / `install` (git or local) / `uninstall` into Gemini skill tiers | Official Gemini installer. |
| **Codex `$skill-installer`** | https://developers.openai.com/codex/skills | Built-in installer for curated / repo skills into Codex | Official Codex local install. |
| **Cursor “Remote Rule (Github)”** | https://cursor.com/docs/skills | UI path to import from GitHub (docs under Skills) | Official Cursor import; not a general manager. |
| **GooseWorks CLI** | https://docs.gooseworks.ai/concepts/cli | Installs **their** skill catalog into Claude/Cursor/Codex; `--all` “across every detected agent” | Catalog-specific, not general skill control. |

**Not verified as general managers (excluded or downgraded):** blog “best of” lists without checking the repo; DeepWiki scrapes; third-party tutorials that restate paths without linking vendor docs.

---

## 2. Do any of them do first-run scanning to detect which agents / skill directories exist?

**Yes — several do agent/tool detection and/or skill-directory scanning.**

| Tool | Detection behavior (from primary sources) |
|------|---------------------------------------------|
| **vercel-labs/skills** | README: *“The CLI automatically detects which coding agents you have installed. If none are detected, you'll be prompted to select which agents to install to.”* ([README](https://github.com/vercel-labs/skills/blob/main/README.md)). Each agent has `detectInstalled` in [`src/agents.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts) (typically `existsSync` on config/home dirs, e.g. `~/.claude`, `~/.cursor`, XDG paths). Separate [`src/detect-agent.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/detect-agent.ts) detects **whether the CLI itself is running inside an AI agent** (via `@vercel/detect-agent`) — not the same as scanning skill roots. |
| **Skills Manager** | `ToolAdapter.is_installed()` probes `relative_detect_dir` under the home/config dir ([`tool_adapters.rs`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/tool_adapters.rs)). `scan_local_skills` walks agent skill dirs for unmanaged `SKILL.md` trees ([`scanner.rs`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/scanner.rs), [`commands/scan.rs`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/commands/scan.rs)). README: Global Workspace lists skills in each agent’s folder **including ones installed outside the app**. First-run dialog is about **backup restore**, not agent scan ([`FirstRunRestoreDialog.tsx`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src/components/FirstRunRestoreDialog.tsx)). |
| **Skilled** | README table: per-agent **Detection** column (e.g. Cursor if `.cursor/`, `.cursorrules`, or `.agents/` exists; Claude if `.claude/` exists) — https://github.com/helincao/skilled |
| **ackness/skill-manager** | `detect_existing_agents()` returns agents whose **global skills path already exists** ([`agents.py`](https://raw.githubusercontent.com/ackness/skill-manager/main/src/skill_manager/agents.py)) |
| **Leogriel** | `leogriel import` / `import from-project` pulls skills already present in agent directories into its store (README) — discovery of **skills**, not a polished first-run agent wizard |
| **GooseWorks** | Docs: `--all` installs across every **detected** coding agent — https://docs.gooseworks.ai/concepts/cli |

**Implication for product:** “Scan on first launch” is an established pattern; the reusable approach is a **registry of (agent → detect dir → skills dir(s))** plus existence checks, optionally followed by recursive `SKILL.md` discovery. Hardcoding only three agents is unnecessary—the hard part is keeping the registry accurate as vendors drift paths (see Codex note below).

---

## 3. Official on-disk locations and skill package layouts (major agents)

### Shared package layout (Agent Skills spec)

Primary: https://agentskills.io/specification · https://agentskills.io/home

- Directory with required **`SKILL.md`**
- Optional: `scripts/`, `references/`, `assets/`, plus any other files
- `SKILL.md` = YAML frontmatter (`name`, `description` required; optional `license`, `compatibility`, `metadata`, experimental `allowed-tools`) + Markdown body
- Progressive disclosure: metadata at startup → body on activation → resources on demand

**The specification does not mandate filesystem roots**—only package contents ([adding-skills-support](https://agentskills.io/client-implementation/adding-skills-support)).

### Cursor

Primary: https://cursor.com/docs/skills · help: https://cursor.com/help/customization/skills

| Scope | Path |
|-------|------|
| Project | `.agents/skills/`, `.cursor/skills/` |
| User | `~/.agents/skills/`, `~/.cursor/skills/` |
| Compatibility (also loaded) | `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/` |

Layout: folder per skill containing `SKILL.md`; optional `scripts/`, `references/`, `assets/`. Cursor walks skills roots recursively (category folders OK). Nested project dirs (e.g. `apps/web/.cursor/skills/`) are discovered and scoped. Cursor-specific frontmatter extras: `paths`, `disable-model-invocation`. Links to agentskills.io as the open standard.

### Claude Code

Primary: https://code.claude.com/docs/en/skills.md

| Scope | Path |
|-------|------|
| Personal | `~/.claude/skills/<name>/SKILL.md` |
| Project | `.claude/skills/<name>/SKILL.md` (also nested under packages; parent walk to repo root) |
| Plugin | `<plugin>/skills/<name>/SKILL.md` |
| Enterprise | managed settings (see docs) |
| Legacy commands | `.claude/commands/*.md` still works; skills preferred |

Follows Agent Skills; adds Claude-specific frontmatter (`disable-model-invocation`, `allowed-tools`, `context: fork`, hooks, etc.). Symlinks of skill dirs are followed for personal/project locations.

### OpenAI Codex / ChatGPT agent skills

Primary docs: https://developers.openai.com/codex/skills  
Source confirmation of roots: [`codex-rs/core-skills/src/loader.rs`](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs)

| Scope | Location (docs + source) |
|-------|---------------------------|
| `REPO` | `.agents/skills` on CWD and every ancestor up to repo root |
| `USER` | `$HOME/.agents/skills` (**preferred**); **deprecated** `$CODEX_HOME/skills` (typically `~/.codex/skills`) still loaded for compatibility |
| `ADMIN` | `/etc/codex/skills` |
| `SYSTEM` | Bundled / cached under `$CODEX_HOME/skills/.system` |

Layout: skill directory + `SKILL.md`; optional `scripts/`, `references/`, `assets/`, and Codex-specific optional `agents/openai.yaml` for UI/policy/dependencies. Symlinked skill folders supported. Local enable/disable via `[[skills.config]]` in `~/.codex/config.toml`.

**Path drift warning:** Several third-party installers still target `~/.codex/skills` / `.codex/skills` as “Codex global/project.” That remains partially valid (deprecated user root + Cursor compatibility loaders), but **OpenAI’s documented authoring path is `.agents/skills` / `~/.agents/skills`**. Skills Manager’s own comments note this tension ([`tool_adapters.rs`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/tool_adapters.rs)).

### Gemini CLI

Primary: https://geminicli.com/docs/cli/skills/

| Tier | Path |
|------|------|
| User | `~/.gemini/skills/` or alias `~/.agents/skills/` |
| Workspace | `.gemini/skills/` or alias `.agents/skills/` |
| Plus | Built-in skills; extension-bundled skills |

`.agents/skills/` alias takes precedence over `.gemini/skills/` within the same tier. CLI: `gemini skills install <git-url>`.

### OpenCode

Primary: https://opencode.ai/docs/skills/ · source MDX: https://raw.githubusercontent.com/sst/opencode/dev/packages/web/src/content/docs/skills.mdx

| Scope | Path |
|-------|------|
| Project native | `.opencode/skills/<name>/SKILL.md` |
| Global native | `~/.config/opencode/skills/<name>/SKILL.md` |
| Claude-compatible | `.claude/skills/`, `~/.claude/skills/` |
| Agent-compatible | `.agents/skills/`, `~/.agents/skills/` |

Walks up to git worktree for project paths. Frontmatter aligned with agentskills.io constraints.

### Goose

Primary (repo docs; agentskills.io client link currently 404 on `block.github.io`): https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/docs/guides/context-engineering/using-skills.md  
Listed on https://agentskills.io/clients

| Recommended | Path |
|-------------|------|
| Global | `~/.agents/skills/<name>/SKILL.md` |
| Project | `.agents/skills/<name>/SKILL.md` |
| Plugins | `~/.agents/plugins/<plugin-name>/` |
| Backward compat | `.goose/skills/`, `.claude/skills/`, `~/.claude/skills/`, plus platform config dirs |

### GitHub Copilot / VS Code

Primary: https://docs.github.com/en/copilot/concepts/agents/about-agent-skills · install how-to: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills  
Client showcase also lists VS Code: https://code.visualstudio.com/docs/copilot/customization/agent-skills

| Scope | Path |
|-------|------|
| Project | `.github/skills`, `.claude/skills`, or `.agents/skills` |
| Personal | `~/.copilot/skills` or `~/.agents/skills` |

Install tooling: `gh skill` (preview). Open standard reference: agentskills/agentskills.

### Amp

Primary: https://ampcode.com/manual/agent-skills.md · listed on https://agentskills.io/clients

| Path | Role |
|------|------|
| `.agents/skills/` | Project |
| `~/.config/agents/skills/`, `~/.agents/skills/`, `~/.config/amp/skills/` | User-wide (precedence order documented) |
| `.claude/skills/`, `~/.claude/skills/` | Compatibility |

### Other clients with first-party skill docs (evidence via agentskills.io clients)

https://agentskills.io/clients lists (non-exhaustive) Junie, ZeroClaw, Autohand Code CLI, OpenHands, Mux, Letta, Firebender, etc., each with an `instructionsUrl`. Treat those URLs as the authority for that product’s roots when expanding scan coverage.

---

## 4. Shared convention emerging vs purely vendor-specific?

### Emerging shared convention — **strong evidence**

1. **Package format: `SKILL.md` + directory** — open standard at agentskills.io; Anthropic originated; widely adopted ([home](https://agentskills.io/home), [clients](https://agentskills.io/clients)).
2. **Cross-client directory: `.agents/skills/` (project) and `~/.agents/skills/` (user)** — explicitly recommended for interoperability in [adding-skills-support](https://agentskills.io/client-implementation/adding-skills-support): *“The `.agents/skills/` paths have emerged as a widely-adopted convention… The Agent Skills specification does not mandate where skill directories live.”* Confirmed in Cursor, Codex, Gemini (alias), OpenCode, Goose, Copilot, Amp docs above.
3. **Optional progressive-disclosure subdirs** (`scripts/`, `references/`, `assets/`) appear in the spec and in Cursor/Claude/OpenAI docs.
4. **Install ecosystem:** `npx skills` + skills.sh + git-URL distribution is becoming the de facto package channel ([vercel-labs/skills](https://github.com/vercel-labs/skills)).

### Still vendor-specific — **also strong evidence**

1. **Native roots** remain: `.cursor/skills`, `~/.claude/skills`, `.opencode/skills`, `.gemini/skills`, `.github/skills`, `~/.copilot/skills`, Windsurf/Codeium paths in third-party tables, etc.
2. **Compatibility shims:** many agents also scan Claude’s paths; Cursor also scans Codex paths; OpenCode scans Claude + `.agents`.
3. **Frontmatter extensions** differ (Claude `context`/`hooks`, Cursor `paths`, Codex `agents/openai.yaml`, Amp `mcp.json` in skill dir).
4. **Third-party manager tables disagree** on some global Codex/Cursor targets (e.g. Cursor project `.agents/skills` vs `.cursor/skills`; Codex `~/.codex/skills` vs `~/.agents/skills`) — always prefer the **vendor doc / vendor source** over installer tables when they conflict.

**Verdict:** Format is converging; **roots are dual-track** (native + `.agents/skills`). A control layer that only understands three hardcoded roots will miss real installs; one that only writes a private library will fight the ecosystem unless it also materializes into agent-visible paths.

---

## Concrete projects found (condensed)

1. **[vercel-labs/skills](https://github.com/vercel-labs/skills)** — `npx skills`; discover + install + update + list across ~70 agents; auto-detect installed agents; git URL sources. **Most important existing tool.**
2. **[xingkongliang/skills-manager](https://github.com/xingkongliang/skills-manager)** — Desktop control plane; scan agent folders; sync; git install; **central library**.
3. **[xFurti/leogriel](https://github.com/xFurti/leogriel)** — Manifest/lock CLI; own store; import/sync/doctor.
4. **[helincao/skilled](https://github.com/helincao/skilled)** — Lockfile + `.agents/skills` canonical + symlinks; agent detection by markers.
5. **[ackness/skill-manager](https://github.com/ackness/skill-manager)** — Python `sm` deploy/list/update; detect by global path existence.
6. **[agentskills/agentskills](https://github.com/agentskills/agentskills)** — Spec + skills-ref validator.
7. **[anthropics/skills](https://github.com/anthropics/skills)** — Example skills corpus.
8. **GitHub `gh skill`** — Official Copilot-oriented skill CLI (docs above).
9. **Gemini / Codex first-party installers** — Vendor-scoped, not cross-agent control layers.

---

## Per-agent skill roots & layout (citation index)

| Agent | Official roots (cite) | Layout |
|-------|----------------------|--------|
| **Cursor** | `.agents/skills/`, `.cursor/skills/`, `~/.agents/skills/`, `~/.cursor/skills/` + Claude/Codex compat ([docs](https://cursor.com/docs/skills)) | `SKILL.md` dir; optional scripts/references/assets |
| **Claude Code** | `~/.claude/skills/`, `.claude/skills/`, plugins, enterprise ([docs](https://code.claude.com/docs/en/skills.md)) | Agent Skills + Claude extras |
| **Codex / ChatGPT** | `.agents/skills` (ancestor walk), `$HOME/.agents/skills`, `/etc/codex/skills`, system bundle; deprecated `$CODEX_HOME/skills` ([docs](https://developers.openai.com/codex/skills), [loader.rs](https://raw.githubusercontent.com/openai/codex/main/codex-rs/core-skills/src/loader.rs)) | `SKILL.md` + optional `agents/openai.yaml` |
| **Gemini CLI** | `~/.gemini/skills` ↔ `~/.agents/skills`; `.gemini/skills` ↔ `.agents/skills` ([docs](https://geminicli.com/docs/cli/skills/)) | Agent Skills |
| **OpenCode** | `.opencode/skills`, `~/.config/opencode/skills`, Claude + `.agents` ([docs](https://opencode.ai/docs/skills/)) | Agent Skills |
| **Goose** | `~/.agents/skills`, `.agents/skills` + legacy Goose/Claude ([using-skills.md](https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/docs/guides/context-engineering/using-skills.md)) | Agent Skills |
| **Copilot** | `.github/skills`, `.claude/skills`, `.agents/skills`; `~/.copilot/skills`, `~/.agents/skills` ([docs](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)) | Agent Skills |
| **Amp** | `.agents/skills`, `~/.config/agents/skills`, `~/.agents/skills`, Amp/Claude paths ([manual](https://ampcode.com/manual/agent-skills.md)) | Agent Skills (+ optional `mcp.json`) |

---

## Gaps / unknowns still blocking a product decision

1. **Canonical store vs overlay.** Product constraint forbids inventing a content store; most mature UIs (Skills Manager, Leogriel, Skilled, ackness) **do** invent one. Closest fit is **vercel-labs/skills-style direct install into agent roots** + metadata index (provenance, git remote, last sync) **outside** skill content—or treat `.agents/skills` as the only write target and symlink from vendor natives (Skilled’s model), accepting that `.agents/skills` is still “a” store, just an ecosystem-conventional one.

2. **Codex path split.** Docs/source prefer `~/.agents/skills` + `.agents/skills`; many installers still use `~/.codex/skills`. A scanner must include **both** to match reality; install targeting needs a deliberate choice.

3. **Cursor dual roots.** Official loads both `.cursor/skills` and `.agents/skills` (and Claude/Codex). “Install once, visible everywhere” is not automatic without multi-target install or shared `.agents/skills`.

4. **Detection heuristics differ.** Existence of `~/.claude` vs existence of `~/.claude/skills` vs project markers (`.cursorrules`) yield different “installed agent” sets. Need a product rule: detect **agent presence**, **skills root presence**, or **skills content**.

5. **Registry maintenance.** vercel-labs/skills agent table is the largest public map but is **third-party** relative to each vendor; paths can lag (Codex already shows this). Prefer vendor docs; use installer tables as a bootstrap list with verification.

6. **Git-only v1 vs ecosystem.** Official Copilot (`gh skill`), Gemini (`gemini skills install`), and Codex (`$skill-installer`) are first-party installers; overlapping them may confuse users if the control layer only speaks “git URL.”

7. **Project vs global vs nested monorepo skills.** Claude, Cursor, Codex, OpenCode all walk ancestors / nested package skills. A control layer “list all skills on machine” is unbounded unless scoped (home globals + selected project roots).

8. **Adoption / longevity of small CLIs.** Skilled / Leogriel / ackness are useful design references but thin adoption vs skills CLI and Skills Manager; do not bet the product solely on their APIs.

9. **Goose docs URL drift.** agentskills.io still links `block.github.io/.../using-skills/`; content currently lives under `aaif-goose/goose` raw docs—confirm before citing the old URL in product UI.

10. **Windows / XDG variance.** OpenCode/Amp/Goose use XDG-style `~/.config/...`; vercel-labs/skills uses `xdg-basedir` in `agents.ts`. Detection must not assume only `~/.<vendor>/`.

---

## Research method notes

- Preferred sources: vendor docs (`cursor.com`, `code.claude.com`, `developers.openai.com`, `geminicli.com`, `opencode.ai`, `docs.github.com`, `ampcode.com`), agentskills.io, and first-party GitHub READMEs/source blobs.
- Cross-checked Codex roots in OpenAI docs **and** `openai/codex` `loader.rs`.
- Did not treat secondary blogs (e.g. Agentic Thinking, BSWEN) as authoritative for paths.
- Stars/activity sampled via GitHub API at research time (2026-07-25): vercel-labs/skills ≈27k★; skills-manager ≈3.3k★; others ≤ low single digits.
