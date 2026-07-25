# First-run Scan UX

Type: grilling
Status: resolved
Blocked by: 01

## Question

What does the user see and decide on first launch (and later re-scan): automatic Scan results, confirming/dismissing detected agents, empty state when nothing is found, and whether any permissions or Project prompts happen before the main Library?

## Answer

**First launch:** automatic silent Scan → land on Skills (or empty Skills with CTAs). Toast when useful (“Found N skills across M adapters”). **No** mandatory summary → Continue gate (simplified vs earlier draft; aligned with UI inventory less-is-more). No per-adapter confirmation checklist on first run (adapter enable/disable can live in Settings later).

**Empty state:** if nothing found, Library empty states with CTAs — Add Source / Add Project (and still allow later Scan).

**Projects / permissions:** never required before Library. Add Project only from Projects tab; macOS filesystem permission prompts only when a chosen path needs them.

**Later Scan:** silent Scan on app launch + manual Scan action; no modal — toast/badge if inventory changed. **Update check** for known Skill Sources is separate (also reasonable on launch) from disk Scan.
