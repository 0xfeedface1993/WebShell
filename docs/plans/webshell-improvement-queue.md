# WebShell Improvement Queue (Superseded)

Parent tracker: `docs/plans/webshell-improvement-plan.md`

## Status
- State: Historical / superseded
- Superseded on: 2026-04-09
- Replacement execution queue: `docs/plans/remote-rule-engine-queue.md`

## Why this queue stopped being authoritative
- Every row in this file assumes the legacy execution model remains the product surface.
- The active implementation moved to a new `WebShell` target backed by a remote-rule engine.
- Legacy code now lives behind a `WebShellLegacy` boundary and is not the default product path.

## Use of this file going forward
- Keep for archaeology only.
- Do not update status here.
- Do not resume work from any `W*` item in this file.
