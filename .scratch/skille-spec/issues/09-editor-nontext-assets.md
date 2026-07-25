# Editor behavior for non-text skill assets

Type: grilling
Status: resolved

## Question

In the v1 editor (full tree, text edit, markdown preview), how should Skille treat non-text or oversized assets under a skill (`scripts/` binaries, images, etc.): list-only, Quick Look, open-in-external, or something else — and does Update diff show them as binary-changed only?

## Answer

**Editor:** Full tree always lists all files. Text files are editable; `SKILL.md` (and other markdown) get markdown preview. Non-text / non-editable types: **Quick Look** when macOS supports it, plus **Open in Finder / default app**. No in-app binary/hex editor.

**Update diff:** Non-text changes appear as **status only** (`added` / `modified` / `deleted` + size). No byte/hex diff. Optional Quick Look only for the **current on-disk** file — not a before/after binary compare. Aligns with all-or-nothing accept per location.

**Oversized text:** if a text file exceeds a reasonable size threshold, treat as view/open-externally rather than loading into the editor buffer (exact threshold left to implementation note in spec).
