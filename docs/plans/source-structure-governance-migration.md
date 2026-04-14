# Source Structure Governance Migration

## Goal

Move WebShell away from broad aggregate Swift files and toward feature-owned, responsibility-owned source directories without changing product behavior during each extraction.

## Baseline Debt

- `WebShellClientKit/Views.swift` and `WebShellAdminKit/Views.swift` contain multiple pages, shell views, shared UI primitives, and theme definitions.
- `WebShellClientKit/Features.swift` and `WebShellAdminKit/Features.swift` contain multiple TCA reducers and app reducers.
- `WebShellClientKit/ClientsAndServices.swift` mixes dependency client declarations, dependency keys, live service composition, HTTP/device services, keychain storage, rule engine bridging, and trace storage.
- `WebShellClientKitTests.swift` and `WebShellAdminKitTests.swift` are monolithic test files.

## Migration Rules

- Do not add new feature behavior to legacy aggregate files.
- Extract the smallest coherent slice when a task touches legacy code.
- Keep behavior-preserving moves separate from behavior changes whenever practical.
- After each extraction, run the relevant Xcode MCP build/test or package tests and the structure audit.
- If extraction is too risky for the current fix, keep the edit narrow and add a note to this plan or the related issue.

## Target Order

1. Create target directories under each Apple kit: `App`, `Features`, and `Shared`.
2. Extract shared UI/theme primitives to `Shared/UI`.
3. Extract app shell/root store factories to `App`.
4. Extract small independent client features first: `InputURL`, `RuleSync`, `Settings`, and `AuthPrompt`.
5. Extract large client features: `Files`, then `Tasks`.
6. Extract admin features one at a time: `AuthSchemaPreview`, `Diagnostics`, `Devices`, `Releases`, then `Rules`.
7. Split dependency clients to `Shared/Clients`, live implementations to `Shared/Services`, and platform/database/keychain code to `Shared/Infrastructure`.
8. Mirror feature boundaries in tests.

## Current Enforcement

Use the generic `project-structure-governance` skill for source-layout work and run:

```bash
/Users/yorl/.codex/skills/project-structure-governance/scripts/audit_structure.py --root /Users/yorl/Downloads/GitHub-Cool/WebShell --config WebShell-SPM/docs/architecture/source-structure-audit.json
```

Use `--fail-on-violations` only after the touched area has migrated or in a future strict gate, because the current baseline intentionally records existing aggregate debt.
