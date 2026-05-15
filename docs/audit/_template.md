<!--
  Audit report template.
  Copy this file, rename to YYYY-MM-DD-{agent}-report.md, fill your section only.
  Delete all HTML comments and sections not owned by your agent before committing.
  Agents that write here: qa-engineer, security-reviewer, release-engineer.
-->

# Audit report

| Field | Value |
|---|---|
| Agent | <!-- qa-engineer / security-reviewer / release-engineer --> |
| Date | <!-- YYYY-MM-DD --> |
| Session ID | <!-- paste from Claude Code session output --> |
| Triggered by | <!-- PR number, commit hash, or task description --> |
| Reviewed scope | <!-- files, features, or release tag in scope --> |

---

## QA Engineer section
<!-- Delete this entire section if agent is not qa-engineer -->

### Coverage
- Domain coverage: <!-- X% (target >80%) -->
- Screens with widget tests: <!-- X / total -->
- Golden tests: <!-- X screens at 2 text scales (1.0, 1.5) -->

### Failures
<!-- bullet: test name → failure reason → recommended fix -->
- none

### Flaky (quarantined)
<!-- bullet: test name → failure pattern → follow-up needed -->
- none

### Gaps
<!-- bullet: flow or use case with no test coverage → risk level -->
- none

### Accessibility findings
<!-- bullet: widget or screen → issue → WCAG criterion → required fix -->
<!-- Example: SessionCard → no Semantics label → WCAG 1.3.1 → wrap in Semantics(label: ...) -->
- none

### Performance findings
<!-- bullet: location → issue → required fix -->
<!-- Example: SessionListScreen → unbounded ListView → add itemCount or paginate -->
- none

### Verdict
<!-- PASS / FAIL + one-line reason -->
-

---

## Security Reviewer section
<!-- Delete this entire section if agent is not security-reviewer -->

### Critical (block merge)
<!-- bullet: finding → risk → required fix -->
<!-- Example: users/{uid} readable by all → data leak → add auth != null check -->
- none

### High (fix before release)
<!-- bullet: finding → risk → recommended fix -->
- none

### Informational
<!-- bullet: note, no action required -->
- none

### JSON report
<!-- Do not remove this block. CI parses it. -->
```json
{
  "agent": "security-reviewer",
  "date": "",
  "findings": [],
  "severity_max": "none",
  "verdict": "",
  "summary": ""
}
```

### Verdict
<!-- APPROVED / BLOCKED + one-line reason -->
-

---

## Release Engineer section
<!-- Delete this entire section if agent is not release-engineer -->

### Pre-release checklist
- [ ] CI green on latest commit: <!-- pass / fail -->
- [ ] QA report present and PASS: <!-- pass / fail -->
- [ ] Security report present and APPROVED: <!-- pass / fail -->
- [ ] No unresolved Critical or High findings: <!-- pass / blocked -->
- [ ] Crashlytics evidence file exists in docs/audit/evidence/: <!-- pass / missing -->
- [ ] No print() calls in codebase: <!-- pass / fail — count found -->
- [ ] No PII in logs confirmed: <!-- pass / fail -->
- [ ] rating_enabled rollback documented in CLAUDE.md: <!-- pass / missing -->
- [ ] Compiles on Android: <!-- pass / fail -->
- [ ] Compiles on Web: <!-- pass / fail -->

### Gate results
- QA: <!-- PASS / FAIL — coverage %, test count -->
- Security: <!-- APPROVED / BLOCKED — severity_max -->
- Crashlytics evidence: <!-- PRESENT / MISSING -->
- Feature flag rollback: <!-- DOCUMENTED / MISSING -->

### Changelog
#### <!-- vX.X.X — YYYY-MM-DD -->

**feat**
- none

**fix**
- none

**chore**
- none

### Verdict
<!-- READY TO TAG / BLOCKED + one-line reason -->
-