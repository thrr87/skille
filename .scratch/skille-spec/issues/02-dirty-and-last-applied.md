# Dirty detection and last-applied snapshot

Type: research
Status: resolved

## Question

For Skille’s update flow (copy install, branch tracking, all-or-nothing accept, conscious discard-local-and-apply), what is a sound, lightweight model of **last-applied** state and **dirty** detection that a Swift macOS app can implement without a merge tool?

Investigate how comparable local tools (and/or git itself) record “what we last wrote” vs “what’s on disk now” vs “what’s on the remote branch,” and recommend a concrete sidecar snapshot approach (e.g. content hash tree, recorded commit SHA + file digests) with trade-offs — cited from primary sources where claims about tools/git behavior are made.

## Answer

**Decision-ready model:** For each skill location, keep three states — **remote tip** (sidecar fetch of tracked branch), **last-applied** (sidecar snapshot of what Skille last wrote), **on disk**. Record last-applied as **`appliedCommitSHA` + per-file SHA-256 digests** (optional `treeDigest`; optional later `statCache`). **Dirty** = disk digests ≠ last-applied; **update available** = remote tip digests ≠ last-applied; **accept** only when clean; **discard-local-and-apply** overwrites all-or-nothing and refreshes the snapshot. Hash raw post-write bytes with CryptoKit (not git blob OIDs). Reject commit-SHA-only, mtime-only, and replace-without-dirty-gate (as in default `npx skills` update).

Full write-up: [`.scratch/research/dirty-and-last-applied.md`](../../research/dirty-and-last-applied.md)
