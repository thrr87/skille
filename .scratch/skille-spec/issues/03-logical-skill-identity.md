# Logical skill identity across skill roots

Type: grilling
Status: resolved

## Question

When the same skill content (or same provenance) appears under multiple skill roots, how does Skille identify and group a **logical skill** versus a per-location instance — by folder name, `SKILL.md` frontmatter `name`, provenance id, path, or some combination — including edge cases (renames, forks, same name unrelated skills, attach-source after discover)?

## Answer

**Provenance-first grouping**, with **Skill Source** as a first-class parent:

- **Skill Source** = normalized git URL + branch. First-class in v1: Add Source → list Agent Skills in the repo → install multi-select → batch update across active locations. A single-skill URL is a Source with one path. Multi-skill examples: ponytail, mattpocock/skills. Cache lives in the sidecar; content still only in skill roots (not a vault).
- **Logical skill** = Skill Source + skill path inside the repo. Same name under different remotes (or forks) = different logical skills. Folder rename in a skill root does not break the group (sidecar keeps provenance key + per-location path).
- **No provenance** (Scan discover only) = orphan per location until Attach source.
- **Attach source** to an existing provenance → after confirmation, orphan **joins** that logical skill as another location (may then show dirty vs remote).

Name/folder-only merging is rejected (false merges).
