# PowerNotifications

PowerNotifications is an iPhone app for writing personal prompts and receiving
them as local notifications throughout your waking hours. The app distributes a
chosen number of prompts across a wake-to-bed window, then reliably repeats that
fixed daily pattern until you save a change or reshuffle it.

Everything stays on the device. V1 has no account, backend, analytics, or cloud
sync.

## Adding many prompts

Settings → Data → Import Prompts accepts a local JSON file, previews valid and
skipped entries, and asks for confirmation before saving. The supported format is:

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

The app also maintains a versioned Swift starter catalog. It inserts four editable
starter prompts through `ModelContext` once per catalog version. Direct SQL edits
are unsupported because SwiftData owns its storage format and lifecycle.

## Requirements

- Xcode 26.5 or newer
- iOS 18 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Generate and open the project

`project.yml` is the source of truth for project configuration. Regenerate the
checked-in Xcode project after changing it:

```sh
xcodegen generate
open PowerNotifications.xcodeproj
```

Choose an iPhone simulator and run the `PowerNotifications` scheme.

## Architecture

Source code is grouped by feature. Each feature owns its views and view models,
while app-wide utilities live under `Core`.

```text
PowerNotifications/
├── App/
├── Core/
│   ├── Formatting/
│   ├── Logging/
│   ├── Notifications/
│   ├── Preferences/
│   └── Scheduling/
├── Features/
│   ├── Onboarding/
│   ├── Prompts/
│   ├── Schedule/
│   └── Settings/
└── Resources/
```

Prompts use SwiftData. Schedule and onboarding preferences use `UserDefaults`,
while Apple's pending notification requests are the source of truth for the
generated pattern. Models stay with their owning feature and system boundaries
are isolated behind small testable services.

V1 explicitly follows the right-sized project path: TDD, privacy-conscious
logging, README/spec/plan updates, and Feature-MVVM without the full-path
database-context or layered-architecture machinery.

The approved behavior is documented in
[`docs/specs/powernotifications-v1.md`](docs/specs/powernotifications-v1.md) and
the additive
[`docs/specs/prompt-import-and-seeding-v1.1.md`](docs/specs/prompt-import-and-seeding-v1.1.md).

## Build and test from the command line

The machine currently selects standalone Command Line Tools, so command-line
examples explicitly select the installed Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PowerNotifications.xcodeproj \
  -scheme PowerNotifications \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  build test
```

The tests use Swift Testing and live in `PowerNotificationsTests`.
