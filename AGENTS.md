# AGENTS.md

Shared context for coding-agent sessions working on WordFinder — Claude Code,
Codex, or anything else. This is the canonical file; `CLAUDE.md` points here.

If something below is wrong or out of date, fix it in the same PR as your change.
Don't let it drift — split-brain context is exactly what this file exists to
prevent, and a copy that disagrees with the code is worse than no copy.

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
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.

## Build & test commands

```bash
# First time only
brew install xcodegen

# Required after cloning, BEFORE the first xcodegen run — project.yml references
# this file via configFiles, and xcodegen hard-fails if it's missing.
cp WordFinder/Config/Team.xcconfig.example WordFinder/Config/Team.xcconfig

# After cloning, or whenever project.yml changes
xcodegen generate

# Build for simulator
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build

# Run the tests
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# If the simulator name is ambiguous/unavailable, use a UDID instead:
xcrun simctl list devices available
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'id=<UDID>' -configuration Debug build
```

`WordFinder/Config/Team.xcconfig` is gitignored and **must exist for any
`xcodegen generate` to succeed**, simulator or device. Copy it from
`Team.xcconfig.example` as shown above. Only real-device builds need a real value
in it — for simulator work the `YOUR_TEAM_ID` placeholder is fine, since simulator
builds are ad-hoc signed.

Test runs print several `CoreData: error: …` lines. That is normal noise from the
test host app booting SwiftData — success is the literal `** TEST SUCCEEDED **`.

## When you change project structure

Adding/removing/moving Swift files under `WordFinder/` or `WordFinderTests/`
doesn't need a `project.yml` edit — XcodeGen's folder-based sources pick them up
on the next `xcodegen generate`. If you change **targets, build settings, or
Info.plist keys**, edit `project.yml` (and `Team.xcconfig.example` if it's a
per-developer signing setting), then run `xcodegen generate` and commit both the
`project.yml` diff and confirmation that `xcodebuild` still succeeds. Never commit
the regenerated `.xcodeproj` itself.

## Architecture premises (see PLAN.md for full detail)

- `WordFinder/Models/DictEntry.swift` is the **shared contract** with the server
  (Cloud Functions). If you change it, the server-side schema and OpenAPI spec
  need to change with it, in the same PR/coordinated PRs. Note the enum case
  `DictSource.mwLearners` maps to the wire value `"mw-learners"` — the Swift case
  name and the JSON string differ.
- SwiftData models (`DictEntryRecord`, `HistoryRecord`) are the local cache —
  `entries`/`history` are separate so repeated lookups of the same word don't
  duplicate dictionary data.
- The camera screen is a continuous live-scan viewfinder (fixed guide box,
  no shutter), not a shutter-based capture flow. See PLAN.md §2 for why.
- Theme (light/dark) is an explicit in-app choice via `@AppStorage`, not
  system-follow.

## Camera/OCR pipeline

Design: [`docs/superpowers/specs/2026-08-19-camera-ocr-design.md`](docs/superpowers/specs/2026-08-19-camera-ocr-design.md).
Remaining work: [`docs/superpowers/plans/2026-08-19-camera-ocr.md`](docs/superpowers/plans/2026-08-19-camera-ocr.md)
(Tasks 1–5 shipped; 6–8 open).

```
CameraView ─────────── still the mock scene (Task 6 wires it)
                              │
ScannerViewRepresentable ─────┤  shipped
DataScannerRecognizer ────────┤
        │
   TextRecognizer (protocol)  ← swap point for AVCaptureSession + Vision
        │
   ScanViewModel ── StabilityDetector   (pure, clock injected)
                 └─ WordTokenizer       (pure, temporary)
```

- `StabilityDetector` and `WordTokenizer` have **no camera or UIKit dependency**.
  Strings in, strings out — which is why they are fully unit-tested on a simulator
  with no camera. Keep it that way.
- `StabilityDetector` takes the current time as a parameter instead of reading a
  clock, so tests drive time directly instead of really waiting 0.6s. Don't
  introduce `Date()`, `Timer`, or concurrency into it.
- `ScanViewModel` knows no camera types. The concrete recognizer is owned by the
  view, behind `TextRecognizer`.

**Two traps worth knowing before you touch this area:**

1. **`ScanViewModel.tick()` must be driven on a timer by the view.**
   `DataScannerViewController`'s delegate is event-driven, not per-frame — point it
   at a blank wall and no callback ever fires, so without `tick()` the 10s timeout
   never trips and the camera stays live forever. Task 6 owns wiring it.
2. **A `TextRecognizer` implementation must emit `nil` when text leaves the box.**
   Otherwise `tick()` re-feeds stale text and settles a word that is no longer in
   frame.

`0.6s` (stability window), `10s` (timeout) and `2` (minimum length) are estimates
awaiting on-device tuning in Task 7. Minimum length is only live in
`WordTokenizer` — `ScanViewModel` filters upstream, so `StabilityDetector`'s copy
is unreachable from the app.

## Design tokens

Colors and fonts are defined once in `WordFinder/Design/` from the Claude Design
system (see `design_prompt_for_claude_design.md`). Use `Color.wf*` and `Font.wf*`;
don't introduce raw hex or ad-hoc `Font.system(...)` sizes for semantic UI.

- The **Primary** role lives in `Assets.xcassets/AccentColor`, reachable as
  `Color.accentColor` — it is deliberately *not* a `wf` token, so don't go looking
  for `Color.wfPrimary`.
- `Color.wf*` tokens are light/dark adaptive via `UITraitCollection`. The
  non-adaptive `Color(hex:)` initializer is for decorative one-offs only
  (e.g. the mock camera background).
- Dictionary content — headwords, definitions, examples — uses serif (New York)
  via `design: .serif`. UI chrome uses SF Pro.

## Current placeholders — don't be surprised by these

- **Camera screen**: `CameraView.swift` still renders the mock blurred-background
  scene and fakes recognition on tap. The pipeline behind it is real; the screen
  is not wired to it yet (Task 6).
- **Dictionary data**: `CameraModels.swift` has hardcoded mock word/definition
  content ("resilient") for `WordDetailSheet`. Once Task 6 lands, the *word list*
  comes from real OCR but the *definitions* are still mock. No dictionary API call
  exists yet.
- **Word tokenization**: `WordTokenizer` splits on whitespace client-side as a
  stopgap. PLAN.md F4 puts tokenization and lemmatization on the server — delete
  that file when the server lands, along with the `usable` filter in
  `ScanViewModel.handle` that also calls it.
- **Server**: Cloud Functions (fallback chain, Firestore cache) don't exist in
  this repo yet. PLAN.md §4–§6 describes the intended design.
- **Favorites**: dropped from the current 3-tab design (camera/history/settings).
  If it comes back, it's a history-item feature, not a separate tab. (PLAN.md §6
  still declares a `FavoriteRecord` model — that's stale, the code intentionally
  implements only `DictEntryRecord` and `HistoryRecord`.)

## Licensing constraint

dictionaryapi.dev is CC BY-SA 3.0 and the Merriam-Webster free key is
non-commercial. The attribution string at the bottom of `SettingsView` is a
license obligation, not decoration — don't remove it while tidying UI.

## Collaboration workflow

- Don't push directly to `main` — short-lived feature branches, PR, squash merge.
  Branch prefixes: `feat/…`, `fix/…`, `chore/…`.
- Review before opening a PR. Keep PRs small — an agent that can produce hundreds
  of lines in one shot needs a human deliberately splitting the work, or review
  becomes the bottleneck.
- PRs touching shared surfaces (`WordFinder/Models/`, `project.yml`,
  `WordFinder/Design/`, or server code once it exists) need review before
  merge. Changes scoped entirely inside your own feature area can self-merge.
- Squash merge leaves the branch looking unmerged to git, since the commit SHAs
  differ. `git branch -d` will refuse; use `-D`.
- Claude Code: `.claude/settings.json` is shared and tracked;
  `.claude/settings.local.json` is per-developer and gitignored. Don't put shared
  config in the local file.
