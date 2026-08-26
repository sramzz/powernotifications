# PowerNotifications

PowerNotifications is an iPhone app for delivering a chosen number of curated
or self-created notifications throughout the day.

The current milestone is a minimal SwiftUI application that displays
“Hello, World!” using a Feature-MVVM structure.

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
│   └── Logging/
├── Features/
│   └── Home/
│       ├── ViewModels/
│       └── Views/
└── Resources/
```

Models should be added inside their owning feature when the feature needs them.
Avoid adding empty layers in anticipation of future work.

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
