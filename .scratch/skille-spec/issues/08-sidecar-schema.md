# Sidecar schema essentials

Type: grilling
Status: resolved
Blocked by: 01, 02, 03

## Question

What essential sidecar records and fields does v1 need (logical skills, locations, provenance, branch, last-applied, git cache pointers, Projects) so Install / Update check / Attach source / dirty handling are fully specified — without over-designing storage tech beyond “Application Support on macOS”?

## Answer

v1 sidecar (Application Support; storage engine unspecified) holds at least:

**SkillRoot** — from adapter registry + Scan: `id`, `adapterId`, `path`, `scope` (global | project), `projectId?`, detection/presence metadata as needed.

**SkillSource** — `id`, `normalizedUrl`, `branch`, `displayName?`, `lastFetchAt`, `cachePath`.

**LogicalSkill** — `id`, `sourceId`, `skillPathInRepo`, `displayName?`.

**Location** — `id`, `skillRootId`, `onDiskPath` (or path relative to root), `logicalSkillId?` (null = orphan), `appliedCommitSHA?`, `fileDigests[]` (`relPath`, `sha256`), `treeDigest?`.

**Project** — `id`, `rootPath`, `addedAt`.

**Scan policy:** each Scan **upserts SkillRoots + Locations** for every discovered `SKILL.md` tree in scope; removals detected by Scan vs disk (mark or delete). Orphans are Locations without `logicalSkillId` until Attach source.

Dirty / update semantics per [Dirty detection and last-applied snapshot](02-dirty-and-last-applied.md) research: remote tip vs last-applied vs disk.
