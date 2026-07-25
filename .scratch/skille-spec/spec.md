# Skille — Product Spec (v1 handoff)

**Status:** handoff-ready  
**Platform:** macOS, native Swift, English UI  
**Audience:** Codex UI visualization, `/to-prd`, later implementation planning  

Related: [`CONTEXT.md`](../../CONTEXT.md) · [UI inventory](prototypes/ui-surface-inventory.md) · [UI viz PNG](prototypes/ui-surface-inventory.png) · [wayfinder map](map.md)

---

## 1. Problem & product intent

Power users keep Agent Skills in many on-disk roots (Cursor, Claude Code, Codex, Copilot, etc.). Skills arrive via git repos (often multi-skill, e.g. ponytail, mattpocock/skills), get edited in place, and drift. Existing managers often invent a **canonical content vault** and sync out — which fights agents that also write their own trees.

**Skille** is a **lightweight local control layer**: discover what is already on disk, edit in place, install from git by **copy** into chosen skill roots, track provenance in a **sidecar**, and update with explicit diff review — without owning skill content and without Node/`npx skills` at runtime.

---

## 2. Glossary

Canonical language lives in [`CONTEXT.md`](../../CONTEXT.md). Spec terms used below: Skill, Skill root, Library, Project, Agent adapter, Scan, Sidecar, Install, Authoring, Update check / accept, Provenance, Skill Source, Logical skill, Attach source.

---

## 3. Personas / primary jobs

**Persona:** a developer who runs one or more AI coding agents on a Mac and maintains local Agent Skills.

| Job | Outcome |
|-----|---------|
| See what I have | Scan globals (+ added Projects); browse logical skills and orphans |
| Pull from a repo library | Add Skill Source; install selected packages into selected roots |
| Stay current | Update check on branch; checklist from Source; per-location diff → accept |
| Edit safely | Full tree editor; markdown preview; no silent overwrite of dirty trees |
| Author locally | New Skill scaffold (name + description) into chosen roots |
| Wire discovered skills | Attach Source so orphans join provenance / update flow |

---

## 4. Normative product rules

1. **Overlay, not vault.** Skill file truth = agent skill roots. Sidecar = control metadata + git fetch cache only (Application Support).
2. **Format.** Agent Skills (`SKILL.md` packages). No proprietary package format. ([agentskills.io](https://agentskills.io))
3. **Install = copy** into selected skill roots. No symlink vault. Roots need not be git checkouts.
4. **Skill Source** is first-class (normalized git URL + branch). Multi-skill repos are normal. Single-skill URL = Source with one path.
5. **Logical skill** = Source + path in repo. **Provenance-first** grouping. Name-only merge is forbidden.
6. **Orphans** (Scan-only) stay separate until Attach Source; attaching to existing provenance **joins** after confirm.
7. **Default install suggestion:** `.agents/skills` / `~/.agents/skills` when the adapter supports it; else native root. Multi-select always allowed.
8. **Update:** track configurable **branch** (default `main`/`master`). Last-applied = `appliedCommitSHA` + per-file SHA-256 digests. Dirty = disk ≠ last-applied. Update available = remote tip ≠ last-applied. Accept all-or-nothing per location; dirty → conscious **Discard local & apply**. No merge UI.
9. **Authoring:** local create + edit only. No in-app publish to git.
10. **Independent Swift implementation** — may bootstrap path knowledge from ecosystem tables; **no** Node/`npx skills` runtime dependency.
11. **English UI.** macOS only for v1.
12. **Less is more UI:** master–detail + few sheets (see §6).

---

## 5. Information architecture & key flows

### IA

Main window tabs: **Sources | Skills | Projects** (Skills is home).

- **Skills:** list = logical skill or orphan; inspector = locations + Edit / Update / Attach Source.
- **Sources:** list = Skill Sources; inspector = packages in repo + Install / Update checklist.
- **Projects:** path list only (+ system folder picker). Project skills still appear on Skills.

### Flows

| Flow | Behavior |
|------|----------|
| **First launch** | Silent Scan (+ optional source update checks) → Skills (or empty CTAs). Toast if useful. No summary wizard. |
| **Re-Scan** | Silent on launch + manual Scan; toast/badge on change. |
| **Add Source** | URL + branch → fetch to sidecar cache → list packages. |
| **Install** | Multi-select skills × multi-select skill roots → copy → record provenance + last-applied. |
| **Source Update** | Checklist of updatable locations → per location Update review. |
| **Skill Update** | From inspector → same Update review. |
| **Update review** | Per-file list; text expandable; binary = status+size; Accept / Reject; dirty gate. |
| **Edit** | Location chooser if needed → Editor (tree, text, md preview; QL / open external for non-text). |
| **New Skill** | Name, description, target roots → Agent Skills scaffold on disk. |
| **Attach Source** | URL + path; join existing logical skill on confirm if match. |

---

## 6. UI surface list

Normative inventory: [prototypes/ui-surface-inventory.md](prototypes/ui-surface-inventory.md).  
Approved five-frame viz: [prototypes/ui-surface-inventory.png](prototypes/ui-surface-inventory.png).

**Chrome:** main window (3 tabs, toolbar Scan / Add Source / New Skill, toast) · Editor.  
**Sheets:** Add Source · Install · Attach Source · New Skill · Update checklist · Update review (incl. dirty).

---

## 7. Domain / data model (sidecar)

Storage engine unspecified; lives under Application Support. Scan **upserts** SkillRoots + Locations for every discovered `SKILL.md` in scope; removals detected vs disk.

| Record | Essential fields |
|--------|------------------|
| **SkillRoot** | `id`, `adapterId`, `path`, `scope` (global \| project), `projectId?` |
| **SkillSource** | `id`, `normalizedUrl`, `branch`, `displayName?`, `lastFetchAt`, `cachePath` |
| **LogicalSkill** | `id`, `sourceId`, `skillPathInRepo`, `displayName?` |
| **Location** | `id`, `skillRootId`, `onDiskPath`, `logicalSkillId?` (null = orphan), `appliedCommitSHA?`, `fileDigests[]` (`relPath`, `sha256`), `treeDigest?` |
| **Project** | `id`, `rootPath`, `addedAt` |

Dirty / update semantics: [research/dirty-and-last-applied.md](../research/dirty-and-last-applied.md).

---

## 8. Adapter registry

**Ship set:** eight vendor-verified adapters — Cursor, Claude Code, Codex, Gemini CLI, OpenCode, Goose, GitHub Copilot/VS Code, Amp.

**Detect:** install/config path (primary); skill-root existence (secondary).  
**Content:** directories with `SKILL.md` under in-scope roots. Do not invent adapter identity from `SKILL.md` alone.  
**Codex:** scan deprecated `$CODEX_HOME/skills`; never default-install there.  
**Cursor:** both `.agents` and `.cursor` pairs; default `.agents`.

Full cited table and policies: [research/v1-adapter-registry.md](../research/v1-adapter-registry.md).  
Ecosystem context: [research/agent-skill-discovery-and-existing-tools.md](../research/agent-skill-discovery-and-existing-tools.md).

---

## 9. Acceptance criteria & definition of done

### This handoff (spec DoD)

- [x] Normative product rules and IA recorded
- [x] Sidecar model + dirty/update model specified
- [x] Adapter policy + research links
- [x] UI inventory + approved viz asset
- [x] Out of scope, open questions, decisions & reasoning
- [ ] Published as GitHub PRD via `/to-prd` (next pipeline step)
- [ ] Implementation issues via `/to-issues` (after PRD)

### Future v1 product (testable)

- [ ] Silent Scan on launch upserts SkillRoots/Locations for globals; manual Scan works
- [ ] Skills list shows logical skills and orphans with location / update / dirty badges
- [ ] Add Source lists packages from a multi-skill git repo; Install copies into selected roots with provenance
- [ ] Default install suggestion prefers `.agents/skills` when supported
- [ ] Source Update checklist → Update review → Accept updates last-applied; Reject leaves disk unchanged
- [ ] Dirty location cannot Accept without Discard local & apply
- [ ] Editor edits text in place; markdown preview; non-text QL/open external; binary diff status-only
- [ ] New Skill creates Agent Skills scaffold from name/description into chosen roots
- [ ] Attach Source joins orphan to existing logical skill when provenance matches (after confirm)
- [ ] Projects add/remove affects Scan scope; no full-disk crawl
- [ ] No Node runtime required for core flows
- [ ] English UI; runs as native macOS app

---

## 10. Out of scope (v1)

- Implementing the app in this wayfinding map (spec only)
- Central content vault / symlink-library architecture
- In-app publish to git; tag/SHA pinning; three-way merge
- Windows / Linux
- Runtime dependency on `npx skills` / Node
- Proprietary skill format
- Plugin/marketplace install channels as Skill Sources (e.g. Claude `/plugin` for ponytail) — only Agent Skills trees on disk / via git
- Full Settings / per-adapter enable UI (fog)
- Visual design polish beyond the approved structural viz

---

## 11. Open questions

From the wayfinder map fog (not blocking this handoff):

- Project persistence details; single vs multi-window Editor
- Rich empty/error copy (git auth failure, invalid package)
- macOS git credential / Keychain assumptions
- Performance bounds for large trees / many skills
- Optional per-location “pinned for checklist defaults” (v1 checklist is explicit each time)
- Exact oversized-text threshold for editor

---

## 12. Research index

| Note | Topic |
|------|--------|
| [agent-skill-discovery-and-existing-tools.md](../research/agent-skill-discovery-and-existing-tools.md) | Ecosystem tools, paths, vault vs overlay tension |
| [v1-adapter-registry.md](../research/v1-adapter-registry.md) | v1 adapters, detect/install policy |
| [dirty-and-last-applied.md](../research/dirty-and-last-applied.md) | Last-applied snapshot + dirty gate |

---

## 13. Decisions & reasoning

| # | Decision | Why |
|---|----------|-----|
| 1 | Destination = handoff spec (then Codex viz → PRD/issues) | Keep planning thin; visuals after IA |
| 2 | Overlay + sidecar, not central library | Agents may update their own trees; Skille must not own/block content |
| 3 | Contrast with Skills Manager vault | Close UX cousin; wrong ownership model for our goals |
| 4 | Skill Source first-class | Real repos (ponytail, mattpocock/skills) are multi-skill libraries |
| 5 | Provenance = URL + path in repo | Monorepo-safe; forks ≠ same skill; renames don’t break groups |
| 6 | Orphans until Attach; attach joins on confirm | Avoid false merges by name |
| 7 | Install = copy; git cache in sidecar | Diff/dirty without making skill roots checkouts; no symlink vault |
| 8 | Branch tracking; SHA+file digests last-applied | Lightweight; blocks silent clobber; matches research |
| 9 | Update checklist then per-location review | Batch control without silent mass overwrite |
| 10 | Sources \| Skills \| Projects; Skills = logical rows | Separates “where from” vs “what I have” vs project scope |
| 11 | Projects = paths only | One inventory (Skills); less duplicate nav |
| 12 | Master–detail + sheets; drop first-run modal | Less is more; toast enough after silent Scan |
| 13 | Swift macOS, English, no `npx` | Lightweight native; clean machines without Node |
| 14 | Authoring = local scaffold only | Publish-to-git balloons scope |
| 15 | Eight vendor-verified adapters | Scan discovers; CLI table is bootstrap not authority |
| 16 | Default suggest `.agents/skills` when supported | Ecosystem convention without becoming an app vault |
| 17 | Non-text: QL + status-only in diff | No fake binary editor; all-or-nothing accept stays simple |

---

*End of handoff spec.*
