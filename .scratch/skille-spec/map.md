# Skille — product spec map

## Destination

Handoff-ready product spec for **Skille**: a lightweight native Swift / macOS desktop control layer over existing Agent Skills on disk (no proprietary format, no content vault). Covers Library (scan globals + user-added Projects), in-place editor (file tree, text edit, markdown preview), git-URL install (copy into multi-selected skill roots; default suggest `.agents/skills` when supported), provenance sidecar in Application Support, update check on tracked branch with per-file diff preview and all-or-nothing accept (dirty → conscious discard-local-and-apply), local authoring with thin name/description form, attach-source for discovered skills, and an independent adapter/scan implementation (no `npx skills` runtime). After the spec, UI visuals are generated in Codex; implementation of the app is out of scope for this map.

## Notes

- Domain: local Agent Skills control plane (Cursor, Claude Code, Codex, and other adapters discovered by Scan).
- Skills every session should consult: `/grilling`, `/domain-modeling`, `/research`, `/prototype` as ticket types require; glossary in [`CONTEXT.md`](../../CONTEXT.md).
- Prior research: [`.scratch/research/agent-skill-discovery-and-existing-tools.md`](../research/agent-skill-discovery-and-existing-tools.md).
- Standing preferences: overlay (skill roots = content truth); sidecar = control only; English UI; copy install; no Node/`npx` runtime; default suggest `.agents/skills` when supported; plan/decide here — do not implement the app on this map.
- Tracker: local markdown (`.scratch/skille-spec/`).

## Decisions so far

<!-- filled as tickets resolve; product decisions from charting grilling live in CONTEXT.md and will be restated into the spec via Assemble -->

- Charting grilling (pre-ticket) — core product shape locked in session; see Destination + `CONTEXT.md` (overlay, Scan, Install copy, Update accept, Authoring scope, Application Support sidecar, Swift/macOS, English UI, independent of `npx skills`).
- [v1 adapter registry for Scan](issues/01-v1-adapter-registry.md) — eight vendor-verified adapters; detect by install/config (skill-root secondary); default install `.agents/skills` when supported; see research note.
- [Dirty detection and last-applied snapshot](issues/02-dirty-and-last-applied.md) — sidecar last-applied = commit SHA + per-file SHA-256 digests; dirty = disk ≠ last-applied; update = remote tip ≠ last-applied; accept blocked until discard-local-and-apply.
- [Logical skill identity across skill roots](issues/03-logical-skill-identity.md) — provenance-first; Skill Source (URL+branch) first-class; logical skill = source+path; orphans until Attach source; attach joins existing group on confirm.
- [Library information architecture](issues/04-library-ia.md) — Sources | Skills | Projects; Skills rows = logical/orphan; Source update via checklist then per-location diff; Editor from detail+location; Projects = path list only.
- [Sidecar schema essentials](issues/08-sidecar-schema.md) — SkillRoot, SkillSource, LogicalSkill, Location (digests), Project; Scan upserts roots+locations; orphans = Location without logicalSkillId.
- [First-run Scan UX](issues/05-first-run-scan-ux.md) — silent scan→Skills+toast (no summary modal); empty CTAs; no forced Project/FDA; silent+manual rescan; source update check separate.
- [Handoff spec outline](issues/06-spec-outline.md) — 13 sections incl. acceptance/DoD and Decisions & reasoning; normative prose+bullets; research linked not restated.
- [Editor behavior for non-text skill assets](issues/09-editor-nontext-assets.md) — QL + open external; diff = status+size only; oversized text not buffered.
- [UI surface inventory for Codex viz](issues/07-ui-surface-inventory.md) — master–detail + sheets; 5-frame PNG approved; see prototypes/.
- [Assemble Skille handoff spec](issues/10-assemble-handoff-spec.md) — handoff spec at [spec.md](spec.md); map destination met; next `/to-prd`.

## Not yet specified

- How Project add/remove persists across launches; single-window vs multi-window.
- Error/empty states (no agents found, git auth failure, invalid/incomplete skill package).
- Git authentication UX on macOS (Keychain / credential helper assumptions).
- Performance bounds for Scan and update checks (many skills / large trees).
- Per-location “pinned/enabled for Source checklist defaults” — optional later; v1 checklist is explicit each time.

## Out of scope

- Implementing the Skille app (code) on this map — destination is the handoff spec only.
- UI visual design polish — deferred to Codex image generation after the spec.
- Central content vault / symlink-library architecture (rejected; see Skills Manager contrast in research note).
- In-app publish to git; tag/SHA pinning; three-way merge UI; Windows/Linux.
- Runtime dependency on `npx skills` / Node.
- Inventing a proprietary skill format.
