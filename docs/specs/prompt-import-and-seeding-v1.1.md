# PowerNotifications v1.1: JSON import and starter catalog

## Outcome

PowerNotifications supports two local prompt-ingestion paths: a user-confirmed
JSON file import and an automatic, versioned catalog inserted through SwiftData.
Neither path uses direct SQL, networking, accounts, or cloud storage.

## JSON contract

```json
{
  "schemaVersion": 1,
  "name": "Morning prompts",
  "prompts": [
    { "text": "What deserves my attention today?" },
    { "text": "Take three slow breaths." }
  ]
}
```

`schemaVersion` and a nonempty `prompts` array are required; `name` is optional.
Only version 1 and at most 1,000 prompt objects are accepted. Each object must
contain a string `text`. Structurally invalid documents are rejected wholesale.
Blank text and text over 280 characters are reported in preview and skipped;
all valid entries remain importable, including duplicate text.

Settings exposes **Import Prompts** and **JSON Format**. A selected document is
fully previewed and requires explicit confirmation. A successful import reports
imported and skipped counts. A failed save leaves the preview available to retry.

## Shared batch behavior

Both ingestion paths use `PromptViewModel.createMany(_:)`. The complete accepted
batch is validated before insertion, is inserted with one SwiftData save, rolls
back on persistence failure, and refreshes an active notification schedule once.
JSON imports generate UUIDs; catalog entries use stable UUIDs.

## Starter catalog

Catalog version 1 contains:

1. What matters most right now?
2. Relax your shoulders.
3. What are you avoiding?
4. Take three slow breaths.

The last successfully applied version is stored in dedicated preferences. Stable
IDs make installation idempotent if saving succeeds before the preference update.
Future versions install only newly introduced entries. Once inserted, catalog
prompts are ordinary editable and deletable prompts and are never restored after
deletion.

New users receive catalog v1 after saving their personal prompt and before the
initial schedule is enabled. Existing users receive it on the first launch after
updating. The app shows one notice when entries are actually added.

## Verification

Automated coverage includes parsing, validation preview, batch atomicity and
rollback, schedule refresh count, catalog idempotency and deltas, crash recovery,
deletion behavior, and onboarding order. Final device checks cover the file
picker, complete preview, import result, starter notice, and notification pattern
replacement.
