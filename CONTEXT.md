# Skille

**Skille** is a local control layer over AI-agent skills that already live on disk in each agent's own skill roots. The app does not invent a parallel skill format or content store.

## Language

**Skill**:
A local Agent Skills package: a directory with required `SKILL.md` (and optional related files) in a layout agents already understand. The app adopts the open Agent Skills convention; it never defines a proprietary skill format.
_Avoid_: Plugin, extension, prompt pack (unless referring to a foreign format); our-format skill

**Skill root**:
A directory on disk where a specific AI agent looks for skills — owned by that agent ecosystem, not by this app. Includes both vendor-native roots (e.g. `~/.claude/skills`, `.cursor/skills`) and the cross-client `.agents/skills` / `~/.agents/skills` convention where agents load it.
_Avoid_: Library path, skills folder (as a synonym for the agent-owned location); app-owned skill store

**Library**:
The set of skills the app discovers across known skill roots — a control-plane view, not a separate store of skill content. Default discovery is user/global skill roots; project skill roots join only when the user adds or opens a project (no full-disk crawl).
_Avoid_: Canonical store, vault (for skill file contents)

**Project**:
A user-added directory whose project-scoped skill roots the app includes in the Library and in install/authoring targets.
_Avoid_: Workspace (unless matching a specific agent's term); automatically crawled repo

**Agent adapter**:
The app's knowledge of one agent's skill roots and on-disk layout — how to discover, install into, and recognize skills for that agent without changing its conventions.
_Avoid_: Integration, connector (unless talking about a remote service)

**Scan**:
A local discovery pass that detects which agent adapters apply on this machine (present skill roots / installs) and what skills they contain. The available agent set is discovered, not a fixed product whitelist.
_Avoid_: Sync, import (for first-run discovery)

**Sidecar**:
Local metadata the app keeps separately from skill files — provenance, update source, tracking state, and git fetch cache — without owning the skill content. On macOS it lives under the app's Application Support directory, not inside agent skill roots.
_Avoid_: Canonical copy, skill database (as the source of truth for files); metadata files dropped into `~/.claude/skills` or similar

**Install**:
Writing a skill from a git source into one or more chosen skill roots by **copying** the skill tree into each agent's existing layout, and recording provenance in the sidecar. Git fetch/cache lives with the sidecar — skill roots are not required to be git checkouts. When an adapter supports it, the default suggested target is the cross-client `.agents/skills` / `~/.agents/skills` root — a shared ecosystem convention, not an app-private vault.
_Avoid_: Sync, deploy (unless a later distinct action); inventing a new package shape; canonical app library; symlink vault

**Authoring**:
Creating a new skill in place under one or more chosen skill roots, using the Agent Skills package shape the target adapter expects, then editing it in the app. v1 create includes a thin metadata form (at least `name` and `description` for `SKILL.md` frontmatter). Publishing to git is out of scope.
_Avoid_: Proprietary scaffold; vault-first create; in-app git publish

**Update check**:
Comparing a skill's current files in a skill root against its recorded git source to see whether a newer version is available. v1 tracks a configurable git **branch** (default `main` / `master`), not tags or pinned SHAs.
_Avoid_: Sync, pull (unless the concrete mechanism is git pull); release-tag tracking (v1)

**Update accept**:
Applying a proposed remote change to a whole skill location after the user has reviewed a per-file diff preview. Acceptance is all-or-nothing for that location, not per hunk. If the location has local edits that would require a merge, apply is blocked until the user consciously chooses discard-local-and-apply (no merge tool in v1).
_Avoid_: Auto-update, silent refresh; partial file apply (in v1); three-way merge UI

**Provenance**:
The recorded git identity for a logical skill in the sidecar: a normalized git URL plus the skill’s path inside that repository (and related tracking state). Absent until the user installs from git or consciously attaches a source. A different URL (e.g. a fork) is a different logical skill. Renaming the folder in a skill root does not break the group — the sidecar keeps the provenance key and the per-location path separately.
_Avoid_: Assumed origin, implicit remote; URL-only identity for monorepos; frontmatter-name identity

**Skill Source**:
A first-class tracked git repository (normalized URL + branch) in the sidecar. Adding a source fetches into the sidecar cache, lists Agent Skills packages found in the repo, and enables install multi-select and batch update across active locations. A single-skill git URL is just a Skill Source that yields one skill path. Examples of multi-skill sources: repos such as ponytail or mattpocock/skills.
_Avoid_: App content vault; marketplace; treating plugin/extension install channels as Skill Sources

**Logical skill**:
The control-plane grouping of one skill package identity: a Skill Source plus that skill’s path inside the repository. Locations under different skill roots that share this provenance belong to the same logical skill; discovered skills without provenance are each their own orphan entry until Attach source.
_Avoid_: Name-based merge; folder-name identity alone

**Attach source**:
The user action that binds a git URL (and skill path) to an already-discovered orphan skill so update checks become possible. If that provenance already identifies a logical skill, the orphan joins that group as another location after confirmation. Auto-detected git `origin` is only a confirmation suggestion, never silent tracking.
_Avoid_: Link, bind (as product verbs); auto-track; silent merge without confirmation
