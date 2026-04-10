# WebShell Improvement Plan (Superseded)

## Status
- State: Historical / superseded
- Superseded on: 2026-04-09
- Replacement source of truth: `docs/plans/remote-rule-engine-plan.md`

## Why this is no longer active
- This tracker targeted hardening and test coverage on the legacy `Condom` / `Dirtyware` / `KeyStore` architecture.
- The project direction changed to a full remote-rule-driven engine rewrite with a new public API.
- Continuing to treat the legacy hardening queue as current work would create the wrong execution order and the wrong handoff context.

## Historical note
- Keep this document only as background on the legacy package layout and prior technical debt.
- Do not use this file for current status, execution order, or handoff decisions.

## Current must-read
1. `docs/plans/remote-rule-engine-plan.md`
2. `docs/plans/remote-rule-engine-queue.md`
3. `docs/plans/remote-rule-engine-validation.md`
