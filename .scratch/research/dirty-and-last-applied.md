# Dirty detection and last-applied snapshot (Skille)

**Summary.** Treat each installed skill location as a **three-way comparison without a merge UI**: (1) **remote tip** on the tracked branch (from sidecar git fetch/cache), (2) **last-applied** (what Skille last successfully wrote into that location), (3) **on disk now**. Record last-applied in the Application Support sidecar as **`appliedCommitSHA` + per-file SHA-256 digests** (plus an optional aggregate tree digest). **Dirty** means on-disk content digests ≠ last-applied digests. **Update available** means remote tip’s skill-tree digests ≠ last-applied. Block update accept while dirty until the user consciously chooses **discard-local-and-apply**; then overwrite the location all-or-nothing and refresh the snapshot. This mirrors git’s working-tree vs index vs HEAD split and the lock/hash patterns used by `npx skills` and Skills Manager, without requiring skill roots to be git checkouts or shipping a merge tool.

---

## 1. Product framing (constraints)

From Skille glossary / destination (not restated as research claims):

- Install = **copy** into agent skill roots; git fetch/cache lives in the **sidecar**.
- Update accept is **all-or-nothing per location**; dirty blocks apply until **discard-local-and-apply**.
- No three-way merge UI in v1.
- Lightweight Swift / macOS.

The research question is only: what sidecar model makes dirty + update-check sound under those constraints.

---

## 2. How comparable systems record the three states

### 2.1 Git: working tree vs index vs HEAD

Git explicitly maintains three related states:

| State | Role |
|-------|------|
| **HEAD** (commit / tree) | Last committed snapshot on the current branch |
| **Index** | Virtual working-tree state: path → object name (blob OID), plus cached `lstat` fields used for cheap dirty checks |
| **Working tree** | Bytes on disk now |

Primary sources:

- `git status` reports (a) index vs HEAD, (b) working tree vs index, and (c) untracked paths. ([git-status](https://git-scm.com/docs/git-status): “differences between the index file and the current HEAD commit”, “differences between the working tree and the index file”, and untracked paths.)
- The index is a virtual tree that “does not necessarily have to, and often does not, match the files in the working tree.” Cached stat info speeds dirty detection; when stats look clean, Git may still content-compare (racy-clean case). ([racy-git](https://git-scm.com/docs/racy-git))
- Content identity for a file is a **blob object ID** computed from typed content (`git hash-object`). ([git-hash-object](https://git-scm.com/docs/git-hash-object))
- Trees list path → object name recursively (`git ls-tree`). ([git-ls-tree](https://git-scm.com/docs/git-ls-tree))
- `git describe --dirty` appends `-dirty` when the working tree has local modifications vs HEAD. ([git-describe](https://git-scm.com/docs/git-describe))

**Mapping for Skille (copy install, not a checkout):**

| Git | Skille |
|-----|--------|
| HEAD / remote tip | Tip of tracked **branch** in sidecar fetch cache |
| Index (“what we last registered”) | **Last-applied** sidecar snapshot for that location |
| Working tree | Skill directory on disk in the agent skill root |

Git’s merge machinery exists to reconcile dirty working trees with incoming trees; Skille v1 **refuses** that path and instead blocks apply until discard-local-and-apply — the same safety instinct as Git’s “don’t stomp local changes,” without implementing merge. ([racy-git](https://git-scm.com/docs/racy-git) notes Git checks working-tree vs index “to avoid stomping on local changes” during patch/branch/merge.)

### 2.2 `vercel-labs/skills` (`npx skills`): lock hashes, replace on update

The dominant Agent Skills installer records provenance in lockfiles and detects **remote** change via folder hashes — but **does not** treat local edits as a first-class dirty gate before overwrite.

**Global lock** (`~/.agents/.skill-lock.json` or `$XDG_STATE_HOME/skills/.skill-lock.json`):

- Per skill: `source`, `sourceUrl`, `ref`, `skillPath`, and **`skillFolderHash`**: GitHub **tree SHA** for the skill folder; “changes when ANY file in the skill folder changes.” ([`src/skill-lock.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/skill-lock.ts))

**Project lock** (`skills-lock.json`):

- Per skill: `computedHash` — **SHA-256 over all files** in the skill directory (relative path + file bytes, sorted by path; skips `.git` / `node_modules`). Comments state this is content-on-disk hashing, unlike the global lock’s GitHub tree SHA. ([`src/local-lock.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/local-lock.ts))

**Update check:** compares latest remote folder hash to locked `skillFolderHash` (GitHub Trees API or clone + `computeSkillFolderHash`). ([`src/update.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/update.ts))

**Apply / install:** copy (and symlink) paths call `cleanAndCreateDirectory` — recursive `rm` then recreate — before writing. ([`src/installer.ts`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/installer.ts)) Upstream issue [#455](https://github.com/vercel-labs/skills/issues/455) documents that `skills update` behaves like reinstall/replace and **local edits are lost**; a preserve-local / conflict mode is requested, not shipped as default.

**Takeaway for Skille:** reuse the *split* of “remote folder identity” vs “on-disk content hash,” but **add** an explicit last-applied snapshot and a dirty gate that `npx skills` currently lacks.

### 2.3 Skills Manager: content-scope hash for change detection

Skills Manager (desktop) hashes a skill’s **content scope** for update badges / diffs:

- Walk files with a shared ignore list (`.git`, `.DS_Store`, `Thumbs.db`, `.gitignore`, `__pycache__`, `*.pyc`).
- SHA-256 over relative path + file bytes (+ executable bits on Unix).
- Same enumeration feeds hashing and source-diff so badge and diff never disagree about which files count. ([`content_hash.rs`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/content_hash.rs))

Architecture still uses a **central library** (out of scope for Skille’s overlay model), but the hash/ignore pattern is directly reusable for sidecar last-applied digests.

### 2.4 npm: integrity + “hidden lockfile” freshness

npm’s `package-lock.json` records `integrity` (SRI, typically sha512) for the **artifact unpacked** at a location; for git dependencies the integrity field may be the commit SHA. ([npm package-lock.json docs](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/))

Separately, npm v7+ keeps `node_modules/.package-lock.json` and trusts it only if package folders match the lock **and** the lockfile’s mtime is at least as recent as referenced package folders — otherwise it re-evaluates. Docs warn that **manual edits inside a package may not bump the package folder mtime**, so mtime-only freshness can miss content edits. ([same docs, “Hidden Lockfiles”](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/))

**Takeaway:** artifact/commit identity ≠ reliable dirty detection of edited on-disk trees; content digests (or full re-walk) are required when users edit files in place.

### 2.5 Homebrew: install receipt, not dirty-vs-last-write

Homebrew writes `INSTALL_RECEIPT.json` (`AbstractTab::FILENAME`) beside each keg with install metadata including `source.tap_git_head` and `time`. ([`Library/Homebrew/tab.rb`](https://raw.githubusercontent.com/Homebrew/brew/master/Library/Homebrew/tab.rb)) Outdatedness is about **formula/version vs cellar**, not “user edited files under Cellar.” Useful as provenance analogy, not as dirty model for editable skill trees.

---

## 3. Recommended model for Skille

### 3.1 Definitions (decision-ready)

For each **tracked skill location** (one skill directory under one skill root):

1. **Remote tip** — After fetch into the sidecar cache: commit SHA at the tracked branch tip, and the file tree of the skill subpath at that commit (bytes as extracted by the same pipeline used for install).
2. **Last-applied** — Sidecar record of what Skille last successfully wrote to that location (install, update accept, or discard-local-and-apply).
3. **On disk** — Current files under that skill directory (content scope; see ignore rules).
4. **Dirty** — Content-scope path set or per-file digests of on disk ≠ last-applied. If no last-applied exists (discovered / authored / attach-source not yet applied), treat as **dirty-unknown** or require an explicit “baseline” action (see §3.5).
5. **Update available** — Remote tip’s content-scope digests ≠ last-applied (independent of dirty).
6. **Safe apply** — Allowed only when **not dirty**. Then all-or-nothing replace location from remote tip and rewrite last-applied.
7. **Discard-local-and-apply** — Conscious overwrite of dirty location from remote tip; then rewrite last-applied. No merge.

### 3.2 Sidecar snapshot schema (concrete)

Store under Application Support (not inside skill roots), keyed by stable location identity (absolute skill directory path or equivalent id from the identity ticket):

```json
{
  "schemaVersion": 1,
  "locationId": "…",
  "skillRootKind": "cursor-user",
  "absolutePath": "/Users/…/.cursor/skills/my-skill",
  "source": {
    "url": "https://github.com/org/repo.git",
    "branch": "main",
    "skillSubpath": "skills/my-skill"
  },
  "lastApplied": {
    "commitSHA": "abc…",
    "appliedAt": "2026-07-25T10:00:00Z",
    "algo": "sha256",
    "files": {
      "SKILL.md": "e3b0c44…",
      "scripts/run.sh": "…"
    },
    "treeDigest": "…"
  },
  "statCache": {
    "SKILL.md": { "size": 1234, "mtimeMs": 1720000000000 },
    "scripts/run.sh": { "size": 80, "mtimeMs": 1720000000000 }
  }
}
```

**Required fields for correctness:** `commitSHA` (provenance / update messaging) + **`files` path→digest map** (dirty + per-file local/remote diffs).

**`treeDigest` (recommended):** SHA-256 over a canonical encoding of sorted `path + "\0" + digest + "\n"` (or path + file bytes). Enables O(1) equality checks once digests are known; still recompute from `files` when writing.

**`statCache` (optional fast path):** size + mtime recorded at apply time, git-index style. If all paths’ current `lstat` match cache **and** no racy timestamp vs snapshot write time, treat as clean without re-reading file bytes; on mismatch or racy case, fall back to content hash. ([racy-git](https://git-scm.com/docs/racy-git); npm hidden-lockfile mtime caveat.) For v1, skills are small — **content-hash every dirty check** is acceptable and simpler; add `statCache` only if Scan/update-check profiling demands it.

### 3.3 Digest algorithm (Swift-friendly)

- **Algorithm:** SHA-256 of **raw file bytes as stored on disk after Skille’s write** (not git blob OIDs). Git blob hashing includes a `blob <size>\0` header and may apply filters (`git hash-object`); Skille should stay filter-free and identical for “bytes we wrote” vs “bytes we read back.” ([git-hash-object](https://git-scm.com/docs/git-hash-object))
- **API:** Apple CryptoKit `SHA256` (`hash(data:)` or incremental `update` / `finalize` for large files). ([SHA256](https://developer.apple.com/documentation/cryptokit/sha256))
- **Path normalization:** relative to skill root; `/` separators; deterministic sort (same idea as [`computeSkillFolderHash`](https://raw.githubusercontent.com/vercel-labs/skills/main/src/local-lock.ts) and Skills Manager [`hash_entries`](https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/content_hash.rs)).
- **Content scope / ignores (v1 suggestion):** skip `.git`, `node_modules`, `.DS_Store`, `Thumbs.db`, `__pycache__`, `*.pyc` (align with Skills Manager + skills CLI). Document that ignored paths are neither dirtied nor updated by Skille.
- **Executable bit:** optional Unix mode bit in digest (Skills Manager includes it). For Agent Skills mostly text/markdown, v1 can omit mode bits unless scripts need `+x` preservation — if install preserves mode, include mode in snapshot or restore modes from remote tree metadata.

### 3.4 Algorithms

**On successful write** (install / accept / discard-local-and-apply):

1. Copy skill tree into location (all-or-nothing; temp dir + atomic replace if feasible).
2. Walk content scope; compute per-file digests; write `lastApplied` + optional `statCache`.
3. Persist `commitSHA` of the source tree that was copied.

**Dirty check:**

1. If no `lastApplied` → not clean (see attach-source baseline).
2. Walk on-disk content scope; build path→digest (or use statCache short-circuit).
3. Dirty iff path set differs or any digest differs.

**Update check:**

1. Fetch tracked branch into sidecar cache.
2. Materialize or walk skill subpath at tip commit; compute path→digest with **same** algorithm.
3. Update available iff that map ≠ `lastApplied.files` (or tip `commitSHA` differs **and** digests differ — prefer digests so empty commits / identical trees don’t false-positive).

**Diff preview (no merge UI):**

- Always show **remote tip vs last-applied** (what accept would write).
- If dirty, also show **on disk vs last-applied** (local drift) and disable Accept until Discard-local-and-apply (or user reverts files outside the app until clean).

**Why not compare disk directly to remote tip for “dirty”?**  
That conflates “I edited locally” with “remote moved.” Git separates index↔worktree from index↔HEAD; Skille should separate last-applied↔disk from last-applied↔remote.

### 3.5 Attach-source / discovered skills

When the user attaches a git URL to an already-on-disk skill:

- Do **not** invent a silent last-applied from remote tip (would falsely mark local edits clean or dirty depending on tip).
- Prefer: compute digests of **current disk** as last-applied baseline **and** record `commitSHA` only after user confirms “treat current files as applied baseline” *or* after first successful apply from a chosen commit.
- Auto-detected `origin` remains confirmation-only (product glossary).

### 3.6 Per-location vs logical skill

Install may copy one logical skill into multiple roots. Dirty and last-applied are **per location** (each copy can diverge). Update accept remains all-or-nothing **per location**, matching product language.

---

## 4. Alternatives and trade-offs

| Approach | How it works | Pros | Cons | Verdict |
|----------|--------------|------|------|---------|
| **A. Recommended: commit SHA + per-file digests in sidecar** | §3 | Dirty + per-file local/remote diffs; works if fetch cache is pruned; Swift CryptoKit; no merge UI | Sidecar JSON grows with file count (fine for skills) | **Choose** |
| **B. Commit SHA only; dirty = hash(disk) vs hash(cache tree @ SHA)** | No file map in sidecar | Smaller sidecar | Dirty check **requires** retained cache of that commit; attach-source awkward; weaker if cache GC’d | Acceptable fallback if cache is durable |
| **C. Single aggregate folder hash only** (`computedHash` / Skills Manager style) | One digest | Tiny; enough for dirty boolean | No per-file local diff list without re-walk+compare anyway; still need remote tree for update preview | OK for badge only; insufficient alone for Skille’s per-file preview |
| **D. Git blob/tree OIDs** (`git hash-object` / `ls-tree`) | Store git object names | Aligns with cache object DB | Filter/`blob` header pitfalls; couples dirty detection to git plumbing in the app | Unnecessary for copy-install overlay |
| **E. Make skill roots real git worktrees** | Standard git dirty | True three-way merge later | Violates copy-install + sidecar-cache product shape; pollutes agent roots with `.git` | Reject for v1 |
| **F. Stat/mtime only** | Like naive npm hidden lock | Fast | Misses same-size same-mtime edits; documented failure mode | Reject as sole signal |
| **G. Full content copies in sidecar** | Mirror bytes | Trivial compare | Heavy; becomes a content vault | Reject |
| **H. `npx skills`-style replace without dirty gate** | Reinstall | Simplest | Loses local edits; contradicts Skille update-accept glossary | Reject |

---

## 5. Recommendation (short)

Implement **last-applied = `{ appliedCommitSHA, files: path→SHA-256, treeDigest }`** in the sidecar; **dirty = disk digests ≠ last-applied**; **update available = remote tip digests ≠ last-applied**; **apply only when clean**; **discard-local-and-apply** refreshes both disk and snapshot. Optionally add git-like **statCache** later. Do not rely on commit SHA alone or mtime alone. Align ignore rules with skills CLI / Skills Manager. Hash with CryptoKit SHA-256 over post-write bytes.

---

## 6. Citations (primary)

1. Git status three-way reporting — https://git-scm.com/docs/git-status  
2. Git index vs working tree; racy-clean content fallback — https://git-scm.com/docs/racy-git  
3. Git blob hashing — https://git-scm.com/docs/git-hash-object  
4. Git tree listing — https://git-scm.com/docs/git-ls-tree  
5. Git describe `--dirty` — https://git-scm.com/docs/git-describe  
6. vercel-labs/skills global lock + `skillFolderHash` — https://raw.githubusercontent.com/vercel-labs/skills/main/src/skill-lock.ts  
7. vercel-labs/skills local lock + `computeSkillFolderHash` — https://raw.githubusercontent.com/vercel-labs/skills/main/src/local-lock.ts  
8. vercel-labs/skills update hash compare — https://raw.githubusercontent.com/vercel-labs/skills/main/src/update.ts  
9. vercel-labs/skills `cleanAndCreateDirectory` overwrite install — https://raw.githubusercontent.com/vercel-labs/skills/main/src/installer.ts  
10. vercel-labs/skills issue: update loses local edits — https://github.com/vercel-labs/skills/issues/455  
11. Skills Manager content hash / ignore scope — https://raw.githubusercontent.com/xingkongliang/skills-manager/main/src-tauri/src/core/content_hash.rs  
12. npm package-lock integrity + hidden lockfile mtime caveats — https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/  
13. Homebrew `INSTALL_RECEIPT.json` / `AbstractTab` — https://raw.githubusercontent.com/Homebrew/brew/master/Library/Homebrew/tab.rb  
14. Apple CryptoKit SHA256 — https://developer.apple.com/documentation/cryptokit/sha256  

---

## 7. Out of scope / deferred

- Three-way merge UI or automatic conflict resolution.
- Exact sidecar JSON schema ownership (ticket `08-sidecar-schema`).
- Logical skill identity across locations (ticket `03-logical-skill-identity`).
- Performance budgets for thousands of skills (map “Not yet specified”).
- Implementing the Skille app.
