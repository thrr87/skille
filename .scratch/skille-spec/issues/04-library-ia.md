# Library information architecture

Type: grilling
Status: resolved
Blocked by: 03

## Question

How is the Library presented in v1: primary navigation (by logical skill, by agent/skill root, by Project vs global), what a row/detail shows, and how multi-location / update-available states appear — enough to drive the handoff spec’s screen list without visual design?

## Answer

**Top-level:** three areas — **Sources | Skills | Projects**.

- **Sources:** Skill Source repos (e.g. ponytail, mattpocock/skills). Detail lists packages in the repo; **Update** uses a **checklist** of skills/locations with updates → user confirms → per selected location the existing diff → accept (or discard-local-and-apply) flow. Dirty locations are not silently included.
- **Skills:** primary inventory. Each **row = logical skill or orphan**. Badges for location count, update available, dirty. Detail lists locations (skill roots); **Editor** opens from detail via location picker (auto-enter if only one location).
- **Projects:** thin scope management only — list of added project paths + Add/Remove. Project-scoped skills still appear on Skills (e.g. Project badge), not a duplicate skill list.

Rejected: agent-root sidebar as primary nav; Skills-as-locations-only; Projects as a second full skill browser.
