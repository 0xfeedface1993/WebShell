# WebShell Admin Rules Management PRD

## Document Status
- State: Active
- Last updated: 2026-04-11
- Product scope owner: WebShell Admin
- Parent product PRD: `docs/product/webshell-platform-prd.md`

## Problem
The current Admin Rules surface behaves like a single raw JSON editor. Operators cannot tell which published bundle or local draft they are editing, whether the draft has unsaved changes, what will happen after a mistaken edit, or whether closing and reopening the app will preserve work. This makes rule publishing risky even though the control plane has release history.

## Goal
Turn the Rules module into a product-grade rule document workspace with list-based management, durable local drafts, visible change state, and simple version recovery before publishing to the control plane.

## User Jobs
- As an operator, I can see all editable local rule documents and which published bundle each draft is based on.
- As an operator, I can create a new rule document from the built-in sample or from the current active/published bundle.
- As an operator, I can edit a rule document and know whether the current editor has unsaved, autosaved, validated, or published changes.
- As an operator, I can close the app and later resume the exact draft I was editing.
- As an operator, I can recover from a bad edit by reverting to the last autosaved revision or resetting to the base version.
- As an operator, I can delete an unwanted local draft without deleting a published backend release.

## Non-Goals
- This is not a visual low-code rule composer.
- This does not replace the backend release history or rollback workflow.
- This does not implement multi-operator collaboration or conflict resolution.
- This does not store end-user provider credentials.

## Product Model
| Concept | Owner | Meaning |
| --- | --- | --- |
| Rule Document | Admin local workspace | Editable rule file with title, base bundle version, and local lifecycle state |
| Draft Revision | Admin local workspace | Autosaved snapshot of one document after edits |
| Published Release | Control plane | Immutable backend record created by publishing a validated bundle |
| Active Bundle | Control plane | Latest non-rolled-back bundle served to clients |

Rule documents are local operator working copies. Publishing creates backend releases, but deleting a local rule document never deletes a backend release.

## Required States
- `clean`: editor content matches the last autosaved document state.
- `dirty`: editor has changes not yet autosaved.
- `autosaving`: an autosave write is in progress.
- `autosaved`: latest editor content was persisted locally.
- `validation failed`: JSON or rule contract validation failed.
- `validated`: latest editor content validated successfully.
- `published`: latest validated editor content was published as a backend release.
- `recovered`: app reopened a previously autosaved document.

## Interaction Design
### Layout
Use a three-zone Rules screen:

1. Left list: rule documents with title, base version, updated time, validation state, and dirty/autosaved badge.
2. Center editor: release note, target group, JSON editor, and primary actions.
3. Right inspector: current document identity, base version, current validation summary, autosave/revision controls, and publish readiness.

### Primary Actions
- `New Draft`: creates a new local document from the default sample bundle.
- `Duplicate`: creates a new local working copy from the selected document.
- `Delete Draft`: removes only the selected local draft.
- `Validate`: validates the selected document.
- `Publish`: publishes the selected document after validation.
- `Revert Draft`: restores the most recent autosaved revision before the current edit.
- `Reset To Base`: restores the document to its base content.

### Autosave
- Editing `rawJSON`, `publishNote`, or `targetGroup` marks the selected document dirty immediately.
- Autosave runs after a short debounce and writes to the local app support directory.
- Closing the app after an autosave must be safe; reopening restores the selected document and displays a recovered/autosaved state.
- Autosave failure must not discard editor content; it should surface a diagnostic message.

### Version Recovery Rules
- `Revert Draft` restores the previous autosaved revision for the selected document.
- `Reset To Base` restores the original base content captured when the document was created.
- Published releases remain visible in the Releases tab and are not deleted by local draft actions.
- If the selected document was deleted or missing on reopen, show an empty state rather than silently selecting an unrelated draft.

## Acceptance Criteria
- Rules screen shows a list of rule documents, not only one editor.
- A selected document clearly shows its base bundle version and local draft status.
- Editing marks the document dirty before autosave completes.
- Autosave persists across app restart.
- Revert and reset operations recover from bad edits without contacting the backend.
- Validate and publish operate on the selected document only.
- Reducer tests cover create, edit/autosave, delete, revert, reset, validate, and publish status transitions.

## Implementation Notes
- Use TCA state for selection, dirty/autosave status, validation state, and publish state.
- Use a local dependency client for persistence; do not access files from SwiftUI views.
- Long-lived or delayed autosave effects must be cancellable and scoped by a clear cancellation ID.
- Use stable document IDs for recovery; never restore by defaulting to the first row if a previously selected document is missing.
