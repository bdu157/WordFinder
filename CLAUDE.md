# CLAUDE.md

Shared context for Claude Code sessions working on WordFinder. Both collaborators'
Claude Code should read this before making changes. If something here is wrong or
out of date, fix it in the same PR as your change — don't let it silently drift,
since that's exactly the kind of split-brain problem this file exists to prevent.

## What this project is

iOS app: point the camera at English text, get an instant English-English
definition. Full product/technical plan: [PLAN.md](PLAN.md). The single most
important design decision there is **§4/§5: business logic lives on the server,
not in the client** — the iOS app is a thin client over a `DictEntry` contract.

## Stack

- SwiftUI + SwiftData, iOS 17+, Swift 5.10
- Project structure is managed by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  via `project.yml`. **`WordFinder.xcodeproj` is gitignored — it is generated,
  not source.** Never hand-edit it or expect `git diff` to show it.

## Build & workflow commands

```bash
# First time only
brew install xcodegen

# After cloning, or whenever project.yml changes
xcodegen generate

# Build for simulator
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build

# If the simulator name is ambiguous/unavailable, use a UDID instead:
xcrun simctl list devices available
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'id=<UDID>' -configuration Debug build
```

Real-device builds need `WordFinder/Config/Team.xcconfig` (gitignored — copy it
from `Team.xcconfig.example` and fill in your own Apple Developer Team ID).
Simulator builds don't need it.

## When you change project structure

Adding/removing/moving Swift files under `WordFinder/` doesn't need any extra
step — XcodeGen's folder-based sources pick them up on the next `xcodegen generate`
(and Xcode's file system synchronized groups reflect Finder-level changes too).
If you change **targets, build settings, or Info.plist keys**, edit `project.yml`
(and `Team.xcconfig.example` if it's a per-developer signing setting), then run
`xcodegen generate` and commit both the `project.yml` diff and confirmation that
`xcodebuild` still succeeds. Never commit the regenerated `.xcodeproj` itself.

## Architecture premises (see PLAN.md for full detail)

- `WordFinder/Models/DictEntry.swift` is the **shared contract** with the server
  (Cloud Functions). If you change it, the server-side schema and OpenAPI spec
  need to change with it, in the same PR/coordinated PRs.
- SwiftData models (`DictEntryRecord`, `HistoryRecord`) are the local cache —
  `entries`/`history` are separate so repeated lookups of the same word don't
  duplicate dictionary data.
- The camera screen is a continuous live-scan viewfinder (fixed guide box,
  no shutter), not a shutter-based capture flow. See PLAN.md §2 for why.
- Theme (light/dark) is an explicit in-app choice via `@AppStorage`, not
  system-follow.

## Current placeholders — don't be surprised by these

- **Camera/OCR**: `CameraView.swift` renders a mock blurred-background scene,
  not a real `AVCaptureSession`. Wiring up Vision framework OCR (vs.
  `VisionKit DataScannerViewController`) is the Week 0 PoC in PLAN.md §8/§10.
- **Dictionary data**: `CameraModels.swift` has hardcoded mock word/definition
  content ("resilient"). No real dictionary API call exists yet.
- **Server**: Cloud Functions (fallback chain, Firestore cache) don't exist in
  this repo yet. PLAN.md §4–§6 describes the intended design.
- **Favorites**: dropped from the current 3-tab design (camera/history/settings).
  If it comes back, it's a history-item feature, not a separate tab.

## Collaboration workflow

- Don't push directly to `main` — short-lived feature branches, PR, squash merge.
  Branch prefixes: `feat/…`, `fix/…`, `chore/…`.
- Run `/code-review` before opening a PR. Keep PRs small — an agent that can
  produce hundreds of lines in one shot needs a human deliberately splitting
  the work, or review becomes the bottleneck.
- PRs touching shared surfaces (`WordFinder/Models/`, `project.yml`,
  `WordFinder/Design/`, or server code once it exists) need review before
  merge. Changes scoped entirely inside your own feature area can self-merge.
- `.claude/settings.local.json` is per-developer (gitignored) — don't try to
  commit shared config into it; shared permissions go in `.claude/settings.json`.
