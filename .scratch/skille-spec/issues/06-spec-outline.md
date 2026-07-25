# Handoff spec outline

Type: grilling
Status: resolved

## Question

What section outline and depth must the Skille handoff spec have so it is sufficient for (a) Codex UI image generation and (b) later implementation planning — including which decisions are normative vs open, and where research assets are linked rather than restated?

## Answer

Handoff spec (English) uses this outline. Depth: **normative prose + acceptance-style bullets**; no visual mocks (Codex viz later); no implementation code. Research tables linked, not fully restated (short policy + annex/link OK).

1. **Problem & product intent**
2. **Glossary** — point at `CONTEXT.md` (summarize only if needed)
3. **Personas / primary jobs**
4. **Normative product rules** — overlay, copy install, Skill Source, provenance-first, dirty/update, English UI, Swift/macOS, no `npx` runtime, etc.
5. **Information architecture** — Sources | Skills | Projects + key flows (first-run, install, source update checklist, editor, authoring, attach source)
6. **UI surface list** — screens/sheets/states (filled by prototype ticket; normative inventory here)
7. **Domain / data model** — SkillRoot, SkillSource, LogicalSkill, Location, Project (+ last-applied/dirty fields)
8. **Adapter registry** — policy summary + link to research / annex table
9. **Acceptance criteria & definition of done** — for the *spec handoff* and for a future v1 product (testable bullets: Scan, Library, Install, Update, Editor, Authoring, Skill Source batch update, etc.)
10. **Out of scope**
11. **Open questions** — remaining fog from the map
12. **Research index** — links to `.scratch/research/*`
13. **Decisions & reasoning** — numbered decisions from charting/grilling with short *why* (this conversation / map Decisions so far), so Codex viz and implementers see trade-offs, not only rules

`/to-prd` may later mirror user stories from jobs + acceptance; this spec remains the product-normative source for viz + planning.
