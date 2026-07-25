# UI surface inventory for Codex viz

Type: prototype
Status: resolved
Blocked by: 04, 05, 06

## Question

Produce a cheap, concrete inventory of v1 UI surfaces (screens/sheets/key states) and a rough structural outline the human can react to — suitable as input to Codex image generation after the spec — without implementing the app or polishing visuals.

## Answer

**Canonical structure (less is more):** one main window with **Sources | Skills | Projects** master–detail; **one Editor**; sheets only for Add Source, Install, Attach Source, New Skill, Update checklist, Update review (diff + accept/reject + dirty gate). Orphans / QL / oversized = states, not screens. First launch: silent Scan → Skills + **toast** (no summary modal).

Full write-up: [prototypes/ui-surface-inventory.md](../prototypes/ui-surface-inventory.md)

**Viz asset (5 surfaces):** [prototypes/ui-surface-inventory.png](../prototypes/ui-surface-inventory.png) — Skills, Sources, Install sheet, Update review (incl. dirty), Editor. Matches the revised inventory; approved.
