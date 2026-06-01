<!--
  Architecture decision record template.
  Copy this file, rename to NNNN-short-slug.md, fill every section.
  Numbering is sequential: check the last file in docs/decisions/ for current N.
  Delete all HTML comments before committing.
  Only the architect agent writes here.
-->

# NNNN — title

| Field | Value |
|---|---|
| Status | <!-- Proposed / Accepted / Rejected / Superseded by NNNN --> |
| Date | <!-- YYYY-MM-DD --> |
| Architect session | <!-- paste from Claude Code session output --> |
| Affects | <!-- feature names or layer names this decision touches --> |

---

## Team approval

<!-- Architect sets Status above to Proposed when done.
     A human must sign below and set Status to Accepted before
     the Flutter Engineer implements this feature. -->

Approved by: <!-- name -->
Date: <!-- YYYY-MM-DD -->
Notes: <!-- conditions or concerns, leave blank if none -->

---

## Problem

<!-- One paragraph. What question needs a decision? What breaks or stays
     ambiguous if no decision is made? Be specific to Study Collab, not generic. -->

---

## Constraints

<!-- Bullet list of non-negotiables that any option must satisfy.
     Always include the domain isolation rule where relevant. -->
-

---

## Options considered

<!-- For each sub-decision, provide a comparison table followed by a short
     recommendation paragraph (max 3 sentences).
     Do not use Pro/Con bullet lists. -->

### Sub-decision N — name

| | Option A | Option B | Option C |
|---|---|---|---|
| Summary | | | |
| Read cost | | | |
| Offline support | | | |
| Write complexity | | | |
| Reversal cost | | | |
| Recommendation | | | |

<!-- One paragraph: which option and why. Max 3 sentences. -->

---

## Decision

<!-- One paragraph. Which option and why, in terms of the constraints above.
     Reference specific Study Collab requirements where relevant:
     KMUTT email gate, Firestore offline cache, rating feature flag,
     student/host RBAC, cross-platform Android and Web. -->

---

## Consequences

<!-- Bullet list. What does this decision change downstream?
     Include effects on other features, agents, or the CI pipeline.
     List concrete file paths, new providers, and analytics events
     that must be declared in lib/core/analytics_events.dart. -->
-

---

## Reversal plan

<!-- If this turns out to be wrong, what are the concrete steps to undo it?
     Name the files, agents, and decision records that would need to change. -->