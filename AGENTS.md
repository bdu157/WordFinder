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

**Write non-ASCII characters as `\u{...}` escapes in test code.** A curly
apostrophe (U+2019) in a test literal was silently mangled twice while being
handed between tools, each time turning a correct test into one that asserted the
wrong thing. Tests always escape — copy `WordTokenizer`'s
`keepsCurlyApostropheInsideWord`.

In production the codebase does both, deliberately: `WordLookupModel.swift:20-21`
escapes its em dashes because a mangled one would ship to users unnoticed, while
`WordTokenizer.swift:30` keeps a literal `’` because the character set it builds
is easier to read that way. Escape when silent corruption would survive review.

### Testing on a device

The camera and OCR cannot be exercised in the simulator — there is no camera, so
`DataScannerViewController` reports itself unavailable. Anything touching the
scan path has to be checked on a real iPhone, which needs a real
`DEVELOPMENT_TEAM` in `Team.xcconfig`.

When locating the built `.app` to install, constrain the path:

```bash
find ~/Library/Developer/Xcode/DerivedData -path '*/Build/Products/Debug-iphoneos/WordFinder.app' \
  -not -path '*Index.noindex*'
```

Without `-not -path '*Index.noindex*'` the search also matches an indexing stub
bundle that has no `Info.plist`, and installing it fails with
`CoreDeviceError 3002` — an error that reads like a device or signing problem
and is actually the wrong bundle.

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

## Camera, OCR and lookup pipeline

Designs: [camera/OCR](docs/superpowers/specs/2026-08-19-camera-ocr-design.md) ·
[word lookup](docs/superpowers/specs/2026-09-21-word-lookup-design.md).
Plans: [camera/OCR](docs/superpowers/plans/2026-08-19-camera-ocr.md) (Tasks 1–7 shipped) ·
[word lookup](docs/superpowers/plans/2026-09-21-word-lookup.md) (step 1 shipped; steps 2–3 open).

The whole chain below is live — scan a word on device and you get a real
definition. Nothing in this diagram is a mock.

```
CameraView ─── live scan, wired to the real pipeline
    │
    ├─ scan ────→ ScannerViewRepresentable ── DataScannerRecognizer
    │                     │
    │             TextRecognizer (protocol)  ← swap point for AVCaptureSession + Vision
    │                     │
    │             ScanViewModel ── StabilityDetector  (pure, clock injected)
    │                          └─ WordTokenizer       (pure, temporary)
    │
    └─ settled ─→ WordListSheet ── tap a word ──→ WordLookupView
                                                       │
                                                  WordLookupModel
                                                       │
                                               DictionaryService (protocol)
                                                       │
                                               DictionaryAPIClient
                                                       │
                                               DictionaryAPIMapper (pure)
```

`WordLookupView` — not the model — decides which sheet to show, from the state the
model publishes:

| `WordLookupModel.State` | View shows |
|---|---|
| `.loading` | `loadingView` |
| `.loaded(DictEntry)` | `WordDetailSheet` |
| `.fallback(DictionaryError)` | `SystemDictionaryView` (iOS built-in dictionary) |

The error is carried *inside* `.fallback`, so `WordLookupView` never matches on
`.notFound` or `.unavailable` directly — the model turns the error into the
notice string at `WordLookupModel.swift:44-47`. That is the one place where the
two cases produce different user-visible text.

- `StabilityDetector` and `WordTokenizer` have **no camera or UIKit dependency**.
  Strings in, strings out — which is why they are fully unit-tested on a simulator
  with no camera. Keep it that way.
- `StabilityDetector` takes the current time as a parameter instead of reading a
  clock, so tests drive time directly instead of really waiting 0.6s. Don't
  introduce `Date()`, `Timer`, or concurrency into it.
- `ScanViewModel` knows no camera types. The concrete recognizer is owned by the
  view, behind `TextRecognizer`.
- `DictionaryAPIMapper` is pure the same way: JSON in, `DictEntry` out, no
  `URLSession`. `DictionaryAPIClient.interpret(status:data:fetchedAt:)` is also
  pure, so every status-code and malformed-payload case is tested without a
  network. The single network call lives in `DictionaryAPIClient.lookUp`
  (`DictionaryAPIClient.swift:42`) — keep it there and nowhere else.

**Three traps worth knowing before you touch this area.** All three cost real
debugging time; two of them only show up on a device.

1. **`ScanViewModel.tick()` must be driven on a timer by the view.**
   `DataScannerViewController`'s delegate is event-driven, not per-frame — point it
   at a blank wall and no callback ever fires, so without `tick()` the timeout
   never trips and the camera stays live forever. A blank wall is precisely the
   case the timeout exists for. `CameraView`'s `.task(id: isScanning)` loop is
   what drives it; don't remove it.
2. **A `TextRecognizer` implementation must emit `nil` when text leaves the box.**
   Otherwise `tick()` re-feeds stale text and settles a word that is no longer in
   frame.
3. **A rect measured inside the safe area cannot be handed to an
   `.ignoresSafeArea()` layer.** The camera preview and the blur mask fill the
   whole screen, so their origin sits above `GeometryReader`'s. Pass them
   `guideRect.offsetBy(dx: safeAreaInsets.leading, dy: safeAreaInsets.top)`
   instead — `CameraView.swift:50` does this. Skip it and the scan region lands a
   top-inset above the brackets, so the app reads a strip of text the user never
   aimed at. This one is invisible in the simulator and was only caught by
   comparing screenshots on a device.

Tuned on device (2026-09-21), these are no longer estimates:

| Constant | Value | Why |
|---|---|---|
| stability window | `0.6s` | felt right in hand; unchanged |
| timeout | `7s` | 10s was too long a wait before the hint appeared |
| minimum length | `2` | unchanged |
| `outsideBlurOpacity` | `0.7` | at `1` the surroundings are too obscured to find the word you want and bring it into the box |

Minimum length is only live in `WordTokenizer` — `ScanViewModel` filters upstream,
so `StabilityDetector`'s copy is unreachable from the app. Tune the tokenizer's.

### Why the lookup gives up after 3 seconds

`DictionaryAPIClient.timeout` is `3`, set on both `timeoutIntervalForRequest` and
`timeoutIntervalForResource` — the request-level one only measures gaps between
bytes, so a slow trickle would otherwise run past the budget.

Three seconds is deliberately short because the upstream source is unreliable.
Measured on 2026-09-21, dictionaryapi.dev took roughly **20 seconds** per request
and answered **HTTP 522** for less common words. That measurement is the reason
the Apple-dictionary fallback exists at all, rather than being a nicety: the
primary source cannot be relied on to answer.

`DictionaryError` has exactly two cases, and the UI says something different for
each — `.notFound` (404) means the word isn't in the online dictionary, while
`.unavailable` (timeout, 522, 5xx, dropped connection, unparseable body) means it
didn't answer. Both fall back to `SystemDictionaryView`, but don't collapse them
into one error: telling someone a word doesn't exist when the server was merely
down is a different and worse lie.

## Design tokens

Colors and fonts are defined once in `WordFinder/Design/` from the Claude Design
system (see `design_prompt_for_claude_design.md`). Use `Color.wf*` and `Font.wf*`;
don't introduce raw hex or ad-hoc `Font.system(...)` sizes for semantic UI.

- The **Primary** role lives in `Assets.xcassets/AccentColor`, reachable as
  `Color.accentColor` — it is deliberately *not* a `wf` token, so don't go looking
  for `Color.wfPrimary`.
- `Color.wf*` tokens are light/dark adaptive via `UITraitCollection`. The
  non-adaptive `Color(hex:)` initializer is for decorative one-offs only — its
  one remaining use is the green status dot in `CameraView`.
- Dictionary content — headwords, definitions, examples — uses serif (New York)
  via `design: .serif`. UI chrome uses SF Pro.

## Current placeholders — don't be surprised by these

- **History is never written**: this is the big one. `HistoryView` queries
  `HistoryRecord` and can delete rows, and `WordFinderApp` registers the
  container — but **nothing anywhere calls `modelContext.insert`**, so the
  History tab is permanently empty. Word lookup step 3 owns this. Before you
  build on history, read §13 of the
  [word-lookup spec](docs/superpowers/specs/2026-09-21-word-lookup-design.md):
  `WordLookupModel.load()` needs a `guard !Task.isCancelled` after its `await`
  before persisting, or a dismissed sheet still writes a row.
- **No pronunciation playback**: `DictionaryAPIMapper` parses `phonetic` and
  `audioUrl`, and the phonetic string is displayed, but there is no speaker
  button and no `AVSpeechSynthesizer` or `AVAudioPlayer` in the project. Word
  lookup step 2 owns this. Note the recorded fixture
  `dictionaryapi-running.json` has an **empty string** as its first
  `phonetics[].audio` — whatever plays audio has to treat that as absent.
- **Torch button does nothing**: `CameraView.swift:187` is a bare `TODO`. Its
  comment says "once the real camera session exists", which is now stale — the
  session is real, so the button just needs wiring to `AVCaptureDevice`.
- **No "Open Settings" button**: when camera permission is denied,
  `ScanViewModel.permissionMessage` tells the user to turn it on in Settings but
  gives them no way to get there. It was dropped from the Task 6 code and missed
  in review; the camera/OCR design records it in §6 예외 처리, under the
  **카메라 권한** heading.
- **`CameraMock` is preview-only now**: `CameraModels.swift` still holds four
  sample terms, used by exactly one `#Preview` in `WordListSheet.swift`. It holds
  no definitions and never reaches a running app. Don't read it as live mock data.
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
non-commercial. Attribution now appears in **two** places, and both are license
obligations rather than decoration — don't remove either while tidying UI:

- `SettingsView.swift:22` — the app-wide credit line
- `WordDetailSheet.swift:140` — the per-entry source footer, which names the
  source the definition actually came from (the name itself is built in
  `sourceAttribution`, just below)

Charging money for this app requires sorting the licenses out first. The
Merriam-Webster free key forbids commercial use outright, and CC BY-SA's
share-alike terms follow the content wherever it goes.

## Collaboration workflow

Two people work this repo. `main` is the shared baseline nobody commits to
directly; all work happens on short-lived branches that land through a PR.

### Branch lifecycle

```bash
# Start work — always re-sync main first. Branching off a stale main is where
# conflicts come from.
git switch main && git pull
git switch -c feat/your-thing

# ... work, commit ...

git push -u origin feat/your-thing
gh pr create --base main
```

If `main` moves while you are working (the other person merged first), catch up
before asking for review:

```bash
git fetch origin && git rebase origin/main
```

After the PR is merged, delete the branch on both sides:

```bash
git switch main && git pull
git branch -D feat/your-thing          # -d refuses; see below
git push origin --delete feat/your-thing
```

**`git branch -d` will refuse after a squash merge.** Squashing rewrites the
commits, so git sees no ancestry even though the content is identical and cannot
tell the branch was merged. `-D` is correct here, not dangerous. The same reason
makes `git rev-list --left-right main...branch` show the branch as "ahead" after
it has landed — compare with `git diff main branch` instead, which will be empty.

### Rules

- Branch prefixes: `feat/…`, `fix/…`, `chore/…`. **Squash merge only** — the
  repo's history is one commit per landed change.
- **If you stack PRs, check each one's base before merging.** This has already
  bitten us. On 2026-09-25, #5 (base `main`), #6 (base `feat/camera-wiring`) and
  #8 (base `feat/camera-device-tuning`) were merged within about a minute of each
  other. GitHub reported all three as "Merged", but #6 and #8 landed in their
  stacked bases rather than in `main`, so the device tuning and the entire
  dictionary feature were missing from `main` while every PR looked done.
  Recovering it took #9.
  Two things follow. First, **"the PR says Merged" is not evidence the work is in
  `main`** — check with `git diff origin/main origin/<branch>`, which is empty
  when the content has really landed. Second, ask the repo owner to turn on
  **"Automatically delete head branches"**: when a base branch disappears on
  merge, GitHub retargets the PRs stacked on it to `main` by itself, which would
  have prevented this outright.
- Review before opening a PR. Keep PRs small — an agent that can produce hundreds
  of lines in one shot needs a human deliberately splitting the work, or review
  becomes the bottleneck.
- PRs touching shared surfaces (`WordFinder/Models/`, `project.yml`,
  `WordFinder/Design/`, or server code once it exists) need review before
  merge. Changes scoped entirely inside your own feature area can self-merge.
- **Split work so you don't edit the same files.** This matters more than any
  rule above — the cheapest merge conflict is the one that never happens. The
  natural seam here is the one PLAN.md §4 already draws: iOS client on one side,
  Cloud Functions on the other, meeting at the `DictEntry` contract. Agree who
  owns which before starting parallel work.
- Claude Code: `.claude/settings.json` is shared and tracked;
  `.claude/settings.local.json` is per-developer and gitignored. Don't put shared
  config in the local file.
