# WebShell Source Structure Governance

This document is the project source of truth for directory layout, file responsibility, and module ownership across the WebShell workspace.

## Ownership

- `WebShell-SPM`: shared rule engine, bundle model, resolver runtime, provider/domain behavior, and shared engine tests.
- `WebShellControlPlane`: Vapor routes, controllers, DTOs, persistence models, migrations, services, and backend tests.
- `WebShellClient-Apple`: end-user Apple app shells plus `WebShellClientKit`.
- `WebShellAdmin-macOS`: admin app shell plus `WebShellAdminKit`.

## Apple Kit Target Layout

Both `WebShellClientKit` and `WebShellAdminKit` should converge on this layout:

```text
Sources/<Kit>/
  App/
  Features/
    <FeatureName>/
      <FeatureName>Feature.swift
      <FeatureName>View.swift
      <FeatureName>Presentation.swift
      <FeatureName>PreviewSupport.swift
      Components/
      Support/
  Shared/
    Clients/
    Services/
    Models/
    UI/
    Infrastructure/
    PreviewSupport/
```

Tests should mirror the production boundary:

```text
Tests/<Kit>Tests/
  Features/<FeatureName>/
  Shared/
```

## File Responsibility

- `*Feature.swift`: TCA reducer, `State`, `Action`, cancellation IDs, and feature-local effect routing.
- `*View.swift`: SwiftUI rendering, store/action binding, and UI event collection.
- `*Presentation.swift`: presentation structs, props, formatting helpers, and view-only derived values.
- `*PreviewSupport.swift`: static preview state, preview stores, fixtures, and mock dependency wiring.
- `Shared/Clients`: TCA dependency clients and dependency keys.
- `Shared/Services`: live service implementations and composition.
- `Shared/Models`: app-wide UI/value models that are not domain contracts.
- `Shared/UI`: reusable shell, styling, components, rows, controls, and layout primitives.
- `Shared/Infrastructure`: platform APIs, filesystem, database, keychain, push, pasteboard, and OS bridges.

## View, Preview, ViewModel, Model

For this TCA codebase, reducer `State` plus actions/effects are the default ViewModel boundary. Do not add a parallel ViewModel unless a non-TCA reference model or platform bridge genuinely requires reference semantics.

Domain models and rule contracts belong in `WebShell-SPM`. App UI state belongs beside its feature. API and persistence DTOs belong beside the service/client that serializes them. Presentation props belong beside the view they drive.

SwiftUI previews must not use live services. Keep preview fixtures in feature-local `*PreviewSupport.swift` or `Shared/PreviewSupport`.

## Legacy Aggregate Freeze

These files are migration debt and must not receive new product behavior:

- `Views.swift`
- `Features.swift`
- `Models.swift`
- `ClientsAndServices.swift`
- monolithic `*Tests.swift`

Allowed changes are narrow compatibility edits, import fixes, or extraction steps that remove code from the aggregate. If a task must leave an edit inside an aggregate file, document the exception in the relevant issue or migration plan.

Run the generic structure audit after structure-sensitive work:

```bash
/Users/yorl/.codex/skills/project-structure-governance/scripts/audit_structure.py --root /Users/yorl/Downloads/GitHub-Cool/WebShell --config WebShell-SPM/docs/architecture/source-structure-audit.json
```
