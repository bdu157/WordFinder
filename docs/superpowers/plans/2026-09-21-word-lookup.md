# 단어 상세 — 사전 조회 1단계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 단어 목록에서 누른 단어의 실제 영영 정의를 상세 시트에 보여주고, 온라인 사전이 3초 안에 답하지 않으면 iOS 내장 사전으로 넘긴다.

**Architecture:** 앱이 dictionaryapi.dev 를 직접 부르되 `DictionaryService` 프로토콜 뒤에 격리해 나중에 서버로 교체한다. 응답은 순수 함수(`DictionaryAPIMapper`, `DictionaryAPIClient.interpret`)로 기존 서버 계약 `DictEntry` 로 바꾸고, `WordLookupModel` 이 로딩·성공·폴백 상태를 관리한다. 네트워크와 UIKit 은 가장자리에만 두어 나머지를 실제 응답 픽스처와 가짜 서비스로 시뮬레이터에서 전부 검증한다.

**Tech Stack:** Swift 5.10, SwiftUI, URLSession, UIKit `UIReferenceLibraryViewController`, Swift Testing, XcodeGen

**Spec:** `docs/superpowers/specs/2026-09-21-word-lookup-design.md`

## Global Constraints

- iOS 17.0 최소, Swift 5.10. **`WordFinder.xcodeproj` 는 절대 손으로 고치지 않고 커밋하지 않는다** (gitignore). 새 `.swift` 파일을 만들면 `xcodegen generate` 를 돌린다. `xcodegen` 은 `/opt/homebrew/bin` 에 있다
- UI 문구는 **전부 영어**. 색은 `Color.wf*` / `Color.accentColor`, 폰트는 `Font.wf*`
- 요청 전체 제한 시간 **3초** (`DictionaryAPIClient.timeout`)
- 품사당 처음 보여줄 뜻 **3개** (`WordDetailSheet.initialDefinitionCount`)
- 실패 안내 문구 (정확히 이대로, em dash 는 `\u{2014}`):
  - `Not in the online dictionary — showing the iOS Dictionary`
  - `Online dictionary didn't respond — showing the iOS Dictionary`
- **`DictEntry` 는 협업자와 약속한 서버 계약이다.** 이번에 허용되는 변경은 `Meaning.synonyms` (선택 항목) 추가, `Equatable` 채택, `fetchedAt` 단위 주석뿐이다
- **ASCII 가 아닌 문자는 소스에 `\u{…}` 이스케이프로 적는다.** 이 프로젝트에서 곡선 아포스트로피가 전달 과정에서 두 번 뭉개진 적이 있다. 계획의 코드는 이미 그렇게 적혀 있다
- `WordFinderTests/Fixtures/dictionaryapi-*.json` 은 2026-09-21 에 실제로 받은 응답이다. **다시 받거나 고치지 않는다** — 테스트가 이 바이트에 맞춰져 있다
- 카메라 파이프라인(`ScanViewModel`, `Scanning/` 아래 파일)은 건드리지 않는다
- 테스트 실행:
  ```bash
  xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```
  콘솔의 `CoreData: error: …` 는 테스트 호스트 앱이 SwiftData 를 띄우며 내는 정상 노이즈다. `** TEST SUCCEEDED **` 만 보면 된다
- 시작 시점 테스트 수: **39**. 태스크마다 기대 개수를 적어 두었다 (Swift Testing 은 인자 여러 개인 `@Test` 를 1개로 센다)

## 이 계획의 코드는 미리 실행해 봤다

Task 1~5 의 코드는 계획을 쓰기 전에 실제로 작성해 빌드(Debug·Release)하고 테스트를 돌려 **57개 전부 통과**를 확인한 뒤 되돌렸다. 아래 코드 블록은 그 파일을 그대로 옮긴 것이다. 값이 이상해 보여도 먼저 보고하고, 임의로 고치지 않는다.

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `WordFinder/Models/DictEntry.swift` | 서버 계약. `Meaning.synonyms` 추가, `Equatable` | 1 |
| `WordFinder/Services/Dictionary/DictionaryAPIMapper.swift` | dictionaryapi.dev JSON → `DictEntry`. 순수 | 2 |
| `WordFinder/Services/Dictionary/DictionaryService.swift` | 프로토콜 + `DictionaryError` | 3 |
| `WordFinder/Services/Dictionary/DictionaryAPIClient.swift` | URLSession 3초 + `interpret` (순수) | 3 |
| `WordFinder/Features/Camera/WordLookupModel.swift` | 로딩·성공·폴백 상태 | 4 |
| `WordFinder/Features/Camera/WordDetailSheet.swift` | 성공 화면 — `DictEntry` 를 받도록 재작성 | 5 |
| `WordFinder/Features/Camera/SystemDictionaryView.swift` | Apple 내장 사전 래퍼 | 5 |
| `WordFinder/Features/Camera/WordLookupView.swift` | 상태별 세 화면 | 5 |
| `WordFinder/Features/Camera/CameraModels.swift` | 목업(`WordDetailPreview` 등) 삭제 | 5 |
| `WordFinder/Features/Camera/CameraView.swift` | 누른 단어를 `WordLookupView` 로 넘김 | 5 |

---

### Task 1: `DictEntry` — 품사 단위 동의어 추가

**Files:**
- Modify: `WordFinder/Models/DictEntry.swift`
- Test: `WordFinderTests/DictEntryTests.swift` (신규)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `DictEntry`, `DictEntry.Meaning`, `DictEntry.Definition` 이 `Equatable`
  - `DictEntry.Meaning(partOfSpeech: String, definitions: [Definition], synonyms: [String]?)` — 멤버와이즈 이니셜라이저에 `synonyms` 가 세 번째로 들어간다
  - `fetchedAt` 은 1970 기준 **초**

스펙 §8. dictionaryapi.dev 의 동의어는 대부분 품사 단위로 오는데 계약에는 뜻 단위 자리밖에 없어서 버려지고 있었다. **선택 항목**이라 이 필드가 없는 옛 JSON 도 읽힌다 — 3단계에서 이 JSON 을 기기에 저장하므로 첫 번째 테스트가 그것을 고정한다. 공유 계약 변경이라 PR 에서 협업자 확인이 필요하다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/DictEntryTests.swift`:

```swift
import Foundation
import Testing
@testable import WordFinder

/// 3단계(히스토리)에서 이 JSON 이 기기에 저장된다. 계약에 항목이 늘어도 이미 저장된 옛 JSON 은
/// 읽혀야 하므로, `Meaning.synonyms` 가 없는 JSON 의 디코딩을 고정한다.
@Test func decodesJSONWithoutMeaningSynonyms() throws {
    let json = """
    {"term":"resilient","lang":"en","type":"word","phonetic":null,"audioUrl":null,
     "meanings":[{"partOfSpeech":"adjective","definitions":[{"definition":"elastic","example":null,"synonyms":null}]}],
     "source":"dictionaryapi","fetchedAt":1789993534}
    """
    let entry = try JSONDecoder().decode(DictEntry.self, from: Data(json.utf8))
    #expect(entry.meanings[0].synonyms == nil)
    #expect(entry.meanings[0].definitions[0].definition == "elastic")
}

@Test func roundTripsMeaningSynonyms() throws {
    let entry = DictEntry(
        term: "resilient", lang: "en", type: .word, phonetic: nil, audioUrl: nil,
        meanings: [DictEntry.Meaning(
            partOfSpeech: "adjective",
            definitions: [DictEntry.Definition(definition: "elastic", example: nil, synonyms: nil)],
            synonyms: ["flexible"]
        )],
        source: .dictionaryapi, fetchedAt: 1789993534
    )
    let decoded = try JSONDecoder().decode(DictEntry.self, from: JSONEncoder().encode(entry))
    #expect(decoded == entry)
}

@Test func mwLearnersEncodesToItsWireValue() throws {
    let data = try JSONEncoder().encode(DictEntry.DictSource.mwLearners)
    #expect(String(decoding: data, as: UTF8.self) == "\"mw-learners\"")
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `Meaning` 이니셜라이저에 `synonyms` 인자가 없고, `DictEntry` 가 `Equatable` 이 아니다

- [ ] **Step 3: 구현**

`WordFinder/Models/DictEntry.swift` 전체를 다음으로 교체한다:

```swift
import Foundation

/// Mirrors the server-side `DictEntry` contract defined in Cloud Functions (see PLAN.md §5).
/// This is the shared schema between client and server — keep it in sync with the OpenAPI spec.
struct DictEntry: Codable, Equatable {
    let term: String
    let lang: String
    let type: EntryType
    let phonetic: String?
    let audioUrl: String?
    let meanings: [Meaning]
    let source: DictSource
    /// 사전에서 가져온 시각. 1970-01-01 UTC 기준 **초** 단위.
    let fetchedAt: Int

    struct Meaning: Codable, Equatable {
        let partOfSpeech: String
        let definitions: [Definition]
        /// 품사 단위 동의어. dictionaryapi.dev 는 동의어를 대부분 뜻이 아니라 여기에 둔다.
        /// 선택 항목이라 이 필드가 없는 JSON — 기기에 이미 저장된 것 포함 — 도 그대로 읽힌다.
        let synonyms: [String]?
    }

    struct Definition: Codable, Equatable {
        let definition: String
        let example: String?
        let synonyms: [String]?
    }

    enum EntryType: String, Codable {
        case word
        case phrase
    }

    enum DictSource: String, Codable {
        case dictionaryapi
        case mwLearners = "mw-learners"
        case oxford
    }
}
```

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, **42**개 통과

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Models/DictEntry.swift WordFinderTests/DictEntryTests.swift
git commit -m "feat: add meaning-level synonyms to the DictEntry contract"
```

---

### Task 2: `DictionaryAPIMapper` — 응답을 `DictEntry` 로

**Files:**
- Create: `WordFinder/Services/Dictionary/DictionaryAPIMapper.swift`
- Test: `WordFinderTests/DictionaryAPIMapperTests.swift` (신규)
- 사용: `WordFinderTests/Fixtures/dictionaryapi-resilient.json`, `dictionaryapi-running.json` (이미 커밋됨)

**Interfaces:**
- Consumes: Task 1 의 `DictEntry` (`Meaning.synonyms` 포함)
- Produces:
  - `enum DictionaryAPIMapper { static func map(_ data: Data, fetchedAt: Int) throws -> DictEntry }`
  - `DictionaryAPIMapper.MappingError.noEntries` (`Equatable`) — 빈 배열
  - JSON 디코딩 실패는 `DecodingError` 를 그대로 던진다 (Task 3 이 받아서 `.unavailable` 로 바꾼다)

변환 규칙은 스펙 §6. 테스트가 고정하는 실제 응답의 특이점:
- `resilient` 는 **발음기호가 아예 없다** → `phonetic == nil`
- `resilient` 의 동의어는 **품사 단위에만** 있다 → `Meaning.synonyms`
- `running` 의 첫 음성 항목은 필드가 없는 게 아니라 **빈 문자열** 이다 → 건너뛰고 두 번째를 골라야 한다
- `running` 의 동사 뜻은 **34개** 다

픽스처는 테스트 소스 위치(`#filePath`)를 기준으로 읽는다. 시뮬레이터에서 동작함을 확인했다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/DictionaryAPIMapperTests.swift`:

```swift
import Foundation
import Testing
@testable import WordFinder

/// `WordFinderTests/Fixtures/` 의 JSON 은 2026-09-21 에 dictionaryapi.dev 에서 실제로 받은 응답이다.
private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@Test func mapsResilientWhichHasNoPhoneticAndOnlyMeaningLevelSynonyms() throws {
    let entry = try DictionaryAPIMapper.map(fixture("dictionaryapi-resilient"), fetchedAt: 1789993534)

    #expect(entry.term == "resilient")
    #expect(entry.lang == "en")
    #expect(entry.type == .word)
    #expect(entry.source == .dictionaryapi)
    #expect(entry.fetchedAt == 1789993534)
    #expect(entry.phonetic == nil)
    #expect(entry.audioUrl == "https://api.dictionaryapi.dev/media/pronunciations/en/resilient-us.mp3")

    #expect(entry.meanings.map(\.partOfSpeech) == ["adjective"])
    let adjective = entry.meanings[0]
    #expect(adjective.definitions.count == 2)
    #expect(adjective.definitions[0].definition
        == "(of objects or substances) Returning quickly to original shape after force is applied; elastic.")
    #expect(adjective.definitions[0].example == nil)
    // 뜻 단위 동의어는 빈 배열로 온다 — nil 로 바꿔 화면이 빈 줄을 그리지 않게 한다.
    #expect(adjective.definitions[0].synonyms == nil)
    // 품사 단위 동의어. 계약에 Meaning.synonyms 를 추가하지 않았다면 버려졌을 값이다.
    #expect(adjective.synonyms == ["bendable", "flexible", "strong"])
}

@Test func mapsRunningWithManyPartsOfSpeechAndAudioOnlyInTheSecondPhonetic() throws {
    let entry = try DictionaryAPIMapper.map(fixture("dictionaryapi-running"), fetchedAt: 0)

    // IPA 는 전달 과정에서 뭉개지지 않도록 코드 포인트로 적는다: /ˈɹʌnɪŋ/
    #expect(entry.phonetic == "/\u{2C8}\u{279}\u{28C}n\u{26A}\u{14B}/")
    // 첫 phonetics 항목의 audio 는 빈 문자열이다. 건너뛰고 두 번째를 골라야 한다.
    #expect(entry.audioUrl == "https://api.dictionaryapi.dev/media/pronunciations/en/running-us.mp3")
    #expect(entry.meanings.map(\.partOfSpeech) == ["verb", "noun", "adjective", "adverb", "preposition"])
    #expect(entry.meanings[0].definitions.count == 34)
    #expect(entry.meanings[0].definitions[0].definition == "To move swiftly.")
    #expect(entry.meanings[2].synonyms == ["runny"])
    #expect(entry.meanings[0].synonyms == nil)
}

/// 합성 데이터 — 실제 픽스처는 두 개 모두 항목이 하나뿐이라 동형이의어 병합을 검증할 수 없다.
@Test func mergesSamePartOfSpeechAcrossEntriesInFirstSeenOrder() throws {
    let json = """
    [
      {"word":"bank","phonetics":[],"meanings":[
        {"partOfSpeech":"noun","definitions":[{"definition":"edge of a river"}],"synonyms":["shore"]}
      ]},
      {"word":"bank","phonetics":[],"meanings":[
        {"partOfSpeech":"noun","definitions":[{"definition":"a financial institution"}],"synonyms":["shore","lender"]},
        {"partOfSpeech":"verb","definitions":[{"definition":"to deposit money","example":"I bank online."}]}
      ]}
    ]
    """
    let entry = try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0)

    #expect(entry.meanings.map(\.partOfSpeech) == ["noun", "verb"])
    #expect(entry.meanings[0].definitions.map(\.definition) == ["edge of a river", "a financial institution"])
    #expect(entry.meanings[0].synonyms == ["shore", "lender"])
    #expect(entry.meanings[1].definitions[0].example == "I bank online.")
}

@Test func marksMultiWordTermsAsPhrases() throws {
    let json = #"[{"word":"take off","phonetics":[],"meanings":[]}]"#
    #expect(try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0).type == .phrase)
}

@Test func rejectsAnEmptyResponseArray() {
    #expect(throws: DictionaryAPIMapper.MappingError.noEntries) {
        try DictionaryAPIMapper.map(Data("[]".utf8), fetchedAt: 0)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'DictionaryAPIMapper' in scope`

- [ ] **Step 3: 구현**

`WordFinder/Services/Dictionary/` 디렉터리를 만들고 `DictionaryAPIMapper.swift`:

```swift
import Foundation

/// dictionaryapi.dev 응답을 `DictEntry` 로 바꾼다.
///
/// 변환 규칙은 설계 문서 `2026-09-21-word-lookup-design.md` §6. 순수 함수라 네트워크 없이
/// 실제 응답 픽스처로 검증한다. 서버가 생기면 서버 쪽 구현이 같은 규칙을 따르면 화면이
/// 똑같이 보인다.
enum DictionaryAPIMapper {
    enum MappingError: Error, Equatable {
        /// 응답 배열이 비어 있다.
        case noEntries
    }

    static func map(_ data: Data, fetchedAt: Int) throws -> DictEntry {
        let entries = try JSONDecoder().decode([APIEntry].self, from: data)
        guard let first = entries.first else { throw MappingError.noEntries }

        return DictEntry(
            term: first.word,
            lang: "en",
            type: first.word.contains(" ") ? .phrase : .word,
            phonetic: phonetic(in: entries),
            audioUrl: audioURL(in: entries),
            meanings: mergedMeanings(from: entries),
            source: .dictionaryapi,
            fetchedAt: fetchedAt
        )
    }

    /// `phonetic` → `phonetics[].text` 순으로, 모든 항목을 통틀어 비어 있지 않은 첫 값.
    /// `resilient` 는 둘 다 없다.
    private static func phonetic(in entries: [APIEntry]) -> String? {
        entries
            .flatMap { [$0.phonetic] + ($0.phonetics ?? []).map(\.text) }
            .lazy.compactMap(nonEmpty).first
    }

    /// 비어 있지 않은 첫 `audio`. `running` 은 첫 항목의 `audio` 가 빈 문자열이고
    /// 두 번째 항목에만 URL 이 있어서, 없는 것뿐 아니라 빈 문자열도 건너뛰어야 한다.
    private static func audioURL(in entries: [APIEntry]) -> String? {
        entries
            .flatMap { ($0.phonetics ?? []).map(\.audio) }
            .lazy.compactMap(nonEmpty).first
    }

    /// 모든 항목의 뜻을 합치되 같은 품사는 하나로 묶는다. 품사는 처음 나온 순서를 유지한다.
    /// 동형이의어는 항목이 여러 개로 오는데, 화면에는 품사당 한 블록만 보여주기 위해서다.
    private static func mergedMeanings(from entries: [APIEntry]) -> [DictEntry.Meaning] {
        var order: [String] = []
        var definitions: [String: [DictEntry.Definition]] = [:]
        var synonyms: [String: [String]] = [:]

        for meaning in entries.flatMap(\.meanings) {
            let pos = meaning.partOfSpeech
            if definitions[pos] == nil {
                order.append(pos)
                definitions[pos] = []
                synonyms[pos] = []
            }
            definitions[pos]! += meaning.definitions.map {
                DictEntry.Definition(
                    definition: $0.definition,
                    example: nonEmpty($0.example),
                    synonyms: deduplicated($0.synonyms ?? [])
                )
            }
            synonyms[pos]! += meaning.synonyms ?? []
        }

        return order.map {
            DictEntry.Meaning(partOfSpeech: $0, definitions: definitions[$0]!, synonyms: deduplicated(synonyms[$0]!))
        }
    }

    /// 순서를 지키며 중복을 없앤다. 비면 `nil` — 화면이 빈 동의어 줄을 그리지 않도록.
    private static func deduplicated(_ values: [String]) -> [String]? {
        var seen = Set<String>()
        let unique = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    // MARK: - dictionaryapi.dev 응답 모양 (쓰는 필드만)

    private struct APIEntry: Decodable {
        let word: String
        let phonetic: String?
        let phonetics: [APIPhonetic]?
        let meanings: [APIMeaning]
    }

    private struct APIPhonetic: Decodable {
        let text: String?
        let audio: String?
    }

    private struct APIMeaning: Decodable {
        let partOfSpeech: String
        let definitions: [APIDefinition]
        let synonyms: [String]?
    }

    private struct APIDefinition: Decodable {
        let definition: String
        let example: String?
        let synonyms: [String]?
    }
}
```

새 디렉터리를 프로젝트에 넣는다:

```bash
export PATH="/opt/homebrew/bin:$PATH"; xcodegen generate
```

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, **47**개 통과

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Services/Dictionary/DictionaryAPIMapper.swift WordFinderTests/DictionaryAPIMapperTests.swift
git commit -m "feat: map dictionaryapi.dev responses to DictEntry"
```

---

### Task 3: `DictionaryService` 와 `DictionaryAPIClient`

**Files:**
- Create: `WordFinder/Services/Dictionary/DictionaryService.swift`
- Create: `WordFinder/Services/Dictionary/DictionaryAPIClient.swift`
- Test: `WordFinderTests/DictionaryAPIClientTests.swift` (신규)

**Interfaces:**
- Consumes: Task 2 의 `DictionaryAPIMapper.map(_:fetchedAt:)`
- Produces:
  - `enum DictionaryError: Error, Equatable { case notFound, unavailable }`
  - `protocol DictionaryService: Sendable { func lookUp(_ term: String) async throws -> DictEntry }`
  - `struct DictionaryAPIClient: DictionaryService`
    - `static let timeout: TimeInterval = 3`
    - `static let shared: DictionaryAPIClient`
    - `static func interpret(status: Int, data: Data, fetchedAt: Int) throws -> DictEntry`

실제 네트워크 호출(`lookUp`)은 유닛 테스트하지 않는다. 상태 코드 해석과 변환만 순수 함수 `interpret` 로 떼어 검증하고, 호출 자체는 Task 6 에서 실기기로 본다.

**3초 제한은 요청 전체 시간이다.** `timeoutIntervalForRequest` 는 "데이터가 안 오는 공백" 기준이라 조금씩 흘려보내는 서버에서는 3초를 넘길 수 있다. 그래서 `timeoutIntervalForResource` 도 함께 3초로 묶는다 — 둘 중 하나를 지우지 말 것.

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/DictionaryAPIClientTests.swift`:

```swift
import Foundation
import Testing
@testable import WordFinder

private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@Test func interprets200AsAMappedEntry() throws {
    let entry = try DictionaryAPIClient.interpret(status: 200, data: fixture("dictionaryapi-resilient"), fetchedAt: 42)
    #expect(entry.term == "resilient")
    #expect(entry.fetchedAt == 42)
}

/// 404 본문은 녹화하지 못했다 — 2026-09-21 에는 없는 단어가 전부 522 로 왔다.
/// 상태 코드만으로 판단하므로 본문은 비워 둔다.
@Test func interprets404AsNotFound() {
    #expect(throws: DictionaryError.notFound) {
        try DictionaryAPIClient.interpret(status: 404, data: Data(), fetchedAt: 0)
    }
}

@Test(arguments: [522, 500, 503, 429])
func interpretsServerErrorsAsUnavailable(status: Int) {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: status, data: Data(), fetchedAt: 0)
    }
}

@Test func interpretsAnUnreadable200AsUnavailable() {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: 200, data: Data("<html>".utf8), fetchedAt: 0)
    }
}

@Test func interpretsAnEmpty200AsUnavailable() {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: 200, data: Data("[]".utf8), fetchedAt: 0)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'DictionaryAPIClient' in scope`

- [ ] **Step 3: 프로토콜 작성**

`WordFinder/Services/Dictionary/DictionaryService.swift`:

```swift
import Foundation

enum DictionaryError: Error, Equatable {
    /// 온라인 사전에 없는 단어 (HTTP 404).
    case notFound
    /// 응답이 없거나 늦거나 해석할 수 없다 — 3초 초과, 522, 5xx, 네트워크 끊김, 깨진 응답.
    case unavailable
}

/// 단어 하나의 사전 항목을 가져온다.
///
/// 프로토콜로 둔 이유: 지금은 앱이 dictionaryapi.dev 를 직접 부르지만, 서버(Cloud Functions)가
/// 생기면 구현체만 바꾸고 화면은 그대로 둔다. 테스트에서 가짜를 넣을 수 있는 것도 같은 이점이다.
protocol DictionaryService: Sendable {
    func lookUp(_ term: String) async throws -> DictEntry
}
```

- [ ] **Step 4: 클라이언트 작성**

`WordFinder/Services/Dictionary/DictionaryAPIClient.swift`:

```swift
import Foundation

/// `DictionaryService` 의 dictionaryapi.dev 구현.
///
/// 임시 구현이다. PLAN.md 는 서버가 앞에서 캐시하고 Merriam-Webster 로 폴백하는 구조를 정했고,
/// 서버가 생기면 이 타입은 교체된다. 2026-09-21 측정으로는 요청마다 약 20초가 걸리고 흔하지
/// 않은 단어는 HTTP 522 가 온다 (설계 문서 §2) — 그래서 3초 안에 못 받으면 포기하고,
/// 화면은 Apple 내장 사전으로 넘긴다.
struct DictionaryAPIClient: DictionaryService {
    /// 요청 전체 제한 시간 (설계 문서 §7).
    static let timeout: TimeInterval = 3

    /// 화면이 뜰 때마다 새 세션을 만들지 않도록 하나를 공유한다.
    static let shared = DictionaryAPIClient()

    private let session: URLSession

    init(session: URLSession = DictionaryAPIClient.makeSession()) {
        self.session = session
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        // timeoutIntervalForRequest 는 "데이터가 안 오는 공백" 기준이라, 조금씩 흘려보내는
        // 서버에서는 3초를 넘길 수 있다. 요청 전체 시간인 Resource 도 같은 값으로 묶는다.
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
    }

    func lookUp(_ term: String) async throws -> DictEntry {
        // 경로 한 조각으로 넣으므로 "/" 도 인코딩한다 — "and/or" 가 경로를 나누지 않도록.
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            throw DictionaryError.notFound
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw DictionaryError.unavailable
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.interpret(status: status, data: data, fetchedAt: Int(Date().timeIntervalSince1970))
    }

    /// 상태 코드와 본문을 `DictEntry` 또는 `DictionaryError` 로 해석한다.
    /// 네트워크와 떼어 둔 순수 함수라 테스트에서 직접 부른다.
    /// 404 는 본문을 보지 않고 상태 코드만으로 판단한다.
    static func interpret(status: Int, data: Data, fetchedAt: Int) throws -> DictEntry {
        switch status {
        case 200:
            do {
                return try DictionaryAPIMapper.map(data, fetchedAt: fetchedAt)
            } catch {
                throw DictionaryError.unavailable
            }
        case 404:
            throw DictionaryError.notFound
        default:
            throw DictionaryError.unavailable
        }
    }
}
```

```bash
export PATH="/opt/homebrew/bin:$PATH"; xcodegen generate
```

- [ ] **Step 5: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, **52**개 통과

- [ ] **Step 6: 커밋**

```bash
git add WordFinder/Services/Dictionary/DictionaryService.swift WordFinder/Services/Dictionary/DictionaryAPIClient.swift WordFinderTests/DictionaryAPIClientTests.swift
git commit -m "feat: add DictionaryService and a dictionaryapi.dev client with a 3s budget"
```

---

### Task 4: `WordLookupModel` — 조회 상태

**Files:**
- Create: `WordFinder/Features/Camera/WordLookupModel.swift`
- Test: `WordFinderTests/WordLookupModelTests.swift` (신규)

**Interfaces:**
- Consumes: Task 3 의 `DictionaryService`, `DictionaryError`
- Produces:
  - `@MainActor @Observable final class WordLookupModel`
    - `init(term: String, service: DictionaryService)`
    - `let term: String`, `private(set) var state: State`
    - `enum State: Equatable { case loading, loaded(DictEntry), fallback(DictionaryError) }`
    - `func load() async`
    - `var fallbackNotice: String?`
    - `static let notFoundNotice: String`, `static let unavailableNotice: String`

모델은 네트워크도 UIKit 도 모른다. 카메라의 `ScanViewModel` 처럼 가짜 서비스로 상태 전이를 전부 검증한다. 제한 시간은 모델이 아니라 클라이언트의 URLSession 설정에 있으므로 여기서는 시계가 필요 없다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/WordLookupModelTests.swift`:

```swift
import Foundation
import Testing
@testable import WordFinder

/// 네트워크 없이 조회 결과를 정해 두는 가짜 사전.
private struct FakeDictionaryService: DictionaryService {
    let result: Result<DictEntry, any Error>
    func lookUp(_ term: String) async throws -> DictEntry { try result.get() }
}

private struct SomeOtherError: Error {}

private let sampleEntry = DictEntry(
    term: "resilient", lang: "en", type: .word, phonetic: nil, audioUrl: nil,
    meanings: [DictEntry.Meaning(
        partOfSpeech: "adjective",
        definitions: [DictEntry.Definition(definition: "elastic", example: nil, synonyms: nil)],
        synonyms: nil
    )],
    source: .dictionaryapi, fetchedAt: 0
)

@Test @MainActor func startsLoadingWithTheTappedTerm() {
    let model = WordLookupModel(term: "resilient", service: FakeDictionaryService(result: .success(sampleEntry)))
    #expect(model.term == "resilient")
    #expect(model.state == .loading)
    #expect(model.fallbackNotice == nil)
}

@Test @MainActor func showsTheEntryWhenTheLookupSucceeds() async {
    let model = WordLookupModel(term: "resilient", service: FakeDictionaryService(result: .success(sampleEntry)))
    await model.load()
    #expect(model.state == .loaded(sampleEntry))
    #expect(model.fallbackNotice == nil)
}

@Test @MainActor func fallsBackWithTheNotFoundNotice() async {
    let model = WordLookupModel(term: "qwxzvbnk", service: FakeDictionaryService(result: .failure(DictionaryError.notFound)))
    await model.load()
    #expect(model.state == .fallback(.notFound))
    #expect(model.fallbackNotice == WordLookupModel.notFoundNotice)
}

@Test @MainActor func fallsBackWithTheUnavailableNotice() async {
    let model = WordLookupModel(term: "urban", service: FakeDictionaryService(result: .failure(DictionaryError.unavailable)))
    await model.load()
    #expect(model.state == .fallback(.unavailable))
    #expect(model.fallbackNotice == WordLookupModel.unavailableNotice)
}

/// 서버 구현체가 `DictionaryError` 가 아닌 에러를 던져도 화면이 멈추지 않고 폴백해야 한다.
@Test @MainActor func treatsAnyOtherErrorAsUnavailable() async {
    let model = WordLookupModel(term: "urban", service: FakeDictionaryService(result: .failure(SomeOtherError())))
    await model.load()
    #expect(model.state == .fallback(.unavailable))
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'WordLookupModel' in scope`

- [ ] **Step 3: 구현**

`WordFinder/Features/Camera/WordLookupModel.swift`:

```swift
import Foundation
import Observation

/// 단어 하나를 사전에서 찾아 상세 시트의 상태를 관리한다.
///
/// 네트워크도 UIKit 도 모른다. `DictionaryService` 너머의 가짜로 상태 전이를 전부 검증한다 —
/// 카메라의 `ScanViewModel` 과 같은 방식이다.
@MainActor
@Observable
final class WordLookupModel {
    enum State: Equatable {
        case loading
        case loaded(DictEntry)
        /// 온라인 사전을 쓸 수 없어 Apple 내장 사전으로 넘긴 상태.
        case fallback(DictionaryError)
    }

    /// 실패 시 Apple 사전 위에 띄우는 안내 (설계 문서 §7). 원인에 따라 사용자가 알아야 할 것이
    /// 달라서 두 가지로 나눈다. em dash 는 전달 과정에서 뭉개지지 않도록 코드 포인트로 적는다.
    static let notFoundNotice = "Not in the online dictionary \u{2014} showing the iOS Dictionary"
    static let unavailableNotice = "Online dictionary didn't respond \u{2014} showing the iOS Dictionary"

    let term: String
    private(set) var state: State = .loading
    private let service: DictionaryService

    init(term: String, service: DictionaryService) {
        self.term = term
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await service.lookUp(term))
        } catch let error as DictionaryError {
            state = .fallback(error)
        } catch {
            state = .fallback(.unavailable)
        }
    }

    var fallbackNotice: String? {
        guard case .fallback(let error) = state else { return nil }
        switch error {
        case .notFound: return Self.notFoundNotice
        case .unavailable: return Self.unavailableNotice
        }
    }
}
```

```bash
export PATH="/opt/homebrew/bin:$PATH"; xcodegen generate
```

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, **57**개 통과

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Features/Camera/WordLookupModel.swift WordFinderTests/WordLookupModelTests.swift
git commit -m "feat: add WordLookupModel with loading, loaded and fallback states"
```

---

### Task 5: 상세 화면 연결

성공 화면을 `DictEntry` 에 맞게 다시 쓰고, 상태별 세 화면을 묶는 `WordLookupView` 와 Apple 사전 래퍼를 만들어 `CameraView` 에 연결한다. 목업은 지운다. 한 파일이라도 빠지면 빌드가 깨지므로 한 태스크로 묶었다.

**Files:**
- Modify (전체 교체): `WordFinder/Features/Camera/WordDetailSheet.swift`
- Create: `WordFinder/Features/Camera/SystemDictionaryView.swift`
- Create: `WordFinder/Features/Camera/WordLookupView.swift`
- Modify (전체 교체): `WordFinder/Features/Camera/CameraModels.swift`
- Modify: `WordFinder/Features/Camera/CameraView.swift` — `sheetContent` 한 곳

**Interfaces:**
- Consumes: Task 4 의 `WordLookupModel`, Task 3 의 `DictionaryAPIClient.shared`, Task 1 의 `DictEntry`
- Produces:
  - `struct WordDetailSheet: View { init(entry: DictEntry) }`, `static let initialDefinitionCount = 3`
  - `struct WordLookupView: View { init(term: String, service: DictionaryService = DictionaryAPIClient.shared) }`
  - `struct SystemDictionaryView: UIViewControllerRepresentable { let term: String }`
  - `WordDetailPreview`, `DefinitionPreview`, `CameraMock.detail` **삭제**. `CameraMock.recognizedWords` 는 `WordListSheet` 프리뷰가 쓰므로 남는다

스펙 §5 의 화면 변경이 전부 이 태스크에 있다: 발음기호 없으면 줄 생략, 품사마다 반복, 품사당 3개 + "Show all N", 품사 단위 동의어, 🔊 버튼 숨김, Captured Context 카드 제거, 하단 문구를 출처 표기로 교체.

**시뮬레이터에서는 이 화면에 도달할 수 없다.** 카메라가 없어서 Scan 을 누르면 "This device can't scan text." 가 뜨고 단어 목록까지 가지 못한다. 이 태스크의 검증은 빌드(Debug 와 Release 둘 다), 테스트, 앱 기동까지다. 화면 동작은 Task 6 에서 실기기로 본다.

**Release 빌드도 확인하는 이유:** 프리뷰용 샘플(`DictEntry.previewResilient`)과 `#Preview` 를 `#if DEBUG` 로 감쌌다. 하나만 감싸면 Release 에서 깨진다.

- [ ] **Step 1: `WordDetailSheet.swift` 전체 교체**

```swift
import SwiftUI

/// 단어 상세 — 사전 항목 하나를 보여준다. `WordLookupView` 가 조회에 성공했을 때 뜬다.
///
/// 레이아웃은 Claude Design 목업을 따른다. 가짜 데이터를 전제로 했던 부분 — 발음 버튼,
/// Captured Context 카드, "Saved to History" 문구 — 은 설계 문서
/// `2026-09-21-word-lookup-design.md` §5 에 따라 뺐다. 발음과 히스토리는 다음 단계에서 되살린다.
struct WordDetailSheet: View {
    let entry: DictEntry

    /// 품사마다 처음에 보여줄 뜻의 개수. `running` 의 동사 뜻은 34개다.
    static let initialDefinitionCount = 3

    @Environment(\.dismiss) private var dismiss
    @State private var expandedPartsOfSpeech: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                // 매퍼가 같은 품사를 하나로 합치므로 품사가 식별자로 유일하다.
                ForEach(entry.meanings, id: \.partOfSpeech) { meaning in
                    meaningSection(meaning)
                }
                footer
            }
        }
        .background(Color.wfBackground)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.term)
                    .font(.wfHeadwordSheet)
                    .foregroundStyle(Color.wfTextPrimary)
                // 발음기호가 없는 단어가 실제로 있다 (resilient).
                if let phonetic = entry.phonetic {
                    Text(phonetic)
                        .font(.wfIPA)
                        .foregroundStyle(Color.wfTextSecondary)
                }
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.wfTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.wfPrimaryTint, in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func meaningSection(_ meaning: DictEntry.Meaning) -> some View {
        let isExpanded = expandedPartsOfSpeech.contains(meaning.partOfSpeech)
        let visible = isExpanded
            ? meaning.definitions
            : Array(meaning.definitions.prefix(Self.initialDefinitionCount))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(meaning.partOfSpeech.uppercased())
                    .font(.wfPOSLabel)
                    .tracking(0.8)
                    .foregroundStyle(Color.accentColor)
                Rectangle().fill(Color.wfSeparator).frame(height: 1)
            }

            ForEach(Array(visible.enumerated()), id: \.offset) { index, definition in
                definitionRow(number: index + 1, definition: definition)
            }

            if visible.count < meaning.definitions.count {
                Button("Show all \(meaning.definitions.count)") {
                    expandedPartsOfSpeech.insert(meaning.partOfSpeech)
                }
                .font(.system(size: 15, weight: .medium))
                .tint(Color.accentColor)
            }

            if let synonyms = meaning.synonyms {
                synonymChips(synonyms)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func definitionRow(number: Int, definition: DictEntry.Definition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.wfDefinition)
                .foregroundStyle(Color.wfTextSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Text(definition.definition)
                    .font(.wfDefinition)
                    .foregroundStyle(Color.wfTextPrimary)
                if let example = definition.example {
                    Text(example)
                        .font(.wfExample)
                        .foregroundStyle(Color.wfTextSecondary)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.wfSeparator).frame(width: 2)
                        }
                }
            }
        }
    }

    /// 동의어가 많으면 가로로 넘친다 — 줄바꿈 대신 가로 스크롤로 한 줄을 지킨다.
    private func synonymChips(_ synonyms: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Synonyms")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wfTextSecondary)
                ForEach(synonyms, id: \.self) { synonym in
                    Text(synonym)
                        .font(.wfWordRow)
                        .foregroundStyle(Color.wfTextPrimary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.wfPrimaryTint, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            // 출처 표기는 라이선스 의무다 (dictionaryapi.dev 는 CC BY-SA).
            Text("Definitions: \(sourceAttribution)")
                .font(.wfCaption)
                .foregroundStyle(Color.wfTextSecondary)
            Spacer()
            Button("Keep scanning") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .tint(Color.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var sourceAttribution: String {
        switch entry.source {
        case .dictionaryapi: return "dictionaryapi.dev (CC BY-SA)"
        case .mwLearners: return "Merriam-Webster Learner's"
        case .oxford: return "Oxford"
        }
    }
}

#if DEBUG
extension DictEntry {
    /// 프리뷰 전용. 실제 응답(`resilient`)처럼 발음기호가 없고 동의어가 품사 단위에만 있다.
    static let previewResilient = DictEntry(
        term: "resilient", lang: "en", type: .word, phonetic: nil,
        audioUrl: "https://api.dictionaryapi.dev/media/pronunciations/en/resilient-us.mp3",
        meanings: [DictEntry.Meaning(
            partOfSpeech: "adjective",
            definitions: [
                DictEntry.Definition(
                    definition: "(of objects or substances) Returning quickly to original shape after force is applied; elastic.",
                    example: nil, synonyms: nil),
                DictEntry.Definition(
                    definition: "(organisms or people, of systems) Returning quickly to normal after damaging events or conditions.",
                    example: nil, synonyms: nil),
            ],
            synonyms: ["bendable", "flexible", "strong"]
        )],
        source: .dictionaryapi, fetchedAt: 0
    )
}

#Preview {
    WordDetailSheet(entry: .previewResilient)
}
#endif
```

- [ ] **Step 2: `SystemDictionaryView.swift` 작성**

```swift
import SwiftUI
import UIKit

/// iOS 내장 영영사전(`UIReferenceLibraryViewController`)을 SwiftUI 에 얹는다.
///
/// 온라인 사전에 없거나 응답하지 않을 때의 폴백이다. 오프라인에서도 동작해서 비행기 모드에서도
/// 뜻이 나온다. 영어 사전을 기기에 내려받지 않았으면 iOS 가 "정의 없음"과 사전 관리 버튼을
/// 보여준다 — iOS 동작이라 여기서 바꿀 수 없다.
struct SystemDictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
```

- [ ] **Step 3: `WordLookupView.swift` 작성**

```swift
import SwiftUI

/// 단어 목록에서 누른 단어의 상세 시트. 조회 상태에 따라 세 화면 중 하나를 보여준다.
///
/// 불러오는 중 → 누른 단어 + 스피너 · 성공 → `WordDetailSheet` ·
/// 실패 → 안내 한 줄 + Apple 내장 사전 (설계 문서 `2026-09-21-word-lookup-design.md` §4, §7).
struct WordLookupView: View {
    @State private var model: WordLookupModel

    init(term: String, service: DictionaryService = DictionaryAPIClient.shared) {
        _model = State(initialValue: WordLookupModel(term: term, service: service))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                loadingView
            case .loaded(let entry):
                WordDetailSheet(entry: entry)
            case .fallback:
                fallbackView
            }
        }
        .task { await model.load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text(model.term)
                .font(.wfHeadwordSheet)
                .foregroundStyle(Color.wfTextPrimary)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wfBackground)
    }

    /// 안내 없이 Apple 화면만 띄우면 사용자는 모양이 갑자기 달라진 이유를 모른다.
    private var fallbackView: some View {
        VStack(spacing: 0) {
            if let notice = model.fallbackNotice {
                Text(notice)
                    .font(.wfCaption)
                    .foregroundStyle(Color.wfTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.wfPrimaryTint)
            }
            SystemDictionaryView(term: model.term)
        }
    }
}
```

- [ ] **Step 4: `CameraModels.swift` 전체 교체 — 목업 삭제**

```swift
import Foundation

/// 스캔이 확정한 단어 하나. `WordTokenizer` 가 만들고 단어 목록 시트가 보여준다.
struct ScannedWord: Identifiable, Equatable {
    let id = UUID()
    let term: String

    /// `id` 는 인스턴스마다 다르므로 단어 자체로 비교한다.
    static func == (lhs: ScannedWord, rhs: ScannedWord) -> Bool {
        lhs.term == rhs.term
    }
}

/// 프리뷰 전용 샘플. 실제 화면은 OCR 결과와 사전 응답을 쓴다.
enum CameraMock {
    static let recognizedWords = [
        ScannedWord(term: "resilient"),
        ScannedWord(term: "urban"),
        ScannedWord(term: "absorb"),
        ScannedWord(term: "shocks"),
    ]
}
```

- [ ] **Step 5: `CameraView.swift` 연결**

`sheetContent` 안에서 상세 화면을 만드는 부분만 바꾼다. 다른 곳은 건드리지 않는다.

```diff
diff --git a/WordFinder/Features/Camera/CameraView.swift b/WordFinder/Features/Camera/CameraView.swift
index 27286e2..94b5383 100644
--- a/WordFinder/Features/Camera/CameraView.swift
+++ b/WordFinder/Features/Camera/CameraView.swift
@@ -111,7 +111,9 @@ struct CameraView: View {
     @ViewBuilder
     private var sheetContent: some View {
         if let detailWord {
-            WordDetailSheet(detail: CameraMock.detail)
+            // 다른 단어를 누르면 새 조회가 돌도록 단어를 식별자로 둔다.
+            WordLookupView(term: detailWord.term)
+                .id(detailWord.term)
                 .presentationDetents([.large])
                 .presentationDragIndicator(.visible)
                 .onDisappear { self.detailWord = nil }
```

`.id(detailWord.term)` 는 지우지 말 것 — 다른 단어를 누르면 뷰가 새로 만들어져야 `@State` 의 모델과 조회가 새로 돈다.

- [ ] **Step 6: 목업 참조가 남지 않았는지 확인**

```bash
grep -rn "CameraMock.detail\|WordDetailPreview\|DefinitionPreview" WordFinder/ || echo "없음"
```

Expected: `없음`

- [ ] **Step 7: Debug·Release 빌드와 테스트**

```bash
export PATH="/opt/homebrew/bin:$PATH"; xcodegen generate
for cfg in Debug Release; do xcodebuild -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration $cfg build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"; done
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 두 설정 모두 `BUILD SUCCEEDED`, 테스트 **57**개 통과

- [ ] **Step 8: 시뮬레이터 기동 확인**

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/WordFinder.app' -maxdepth 6 -type d | head -1)
xcrun simctl install booted "$APP" && xcrun simctl launch booted com.wordfinder.app
sleep 5; xcrun simctl spawn booted launchctl list | grep -i wordfinder
```

Expected: 앱이 5초 뒤에도 떠 있다

- [ ] **Step 9: 커밋**

```bash
git add WordFinder/Features/Camera/WordDetailSheet.swift WordFinder/Features/Camera/SystemDictionaryView.swift WordFinder/Features/Camera/WordLookupView.swift WordFinder/Features/Camera/CameraModels.swift WordFinder/Features/Camera/CameraView.swift
git commit -m "feat: show the real definition of the tapped word, falling back to the iOS dictionary"
```

---

### Task 6: 실기기 확인과 PR

사람이 폰을 들고 확인해야 하는 태스크다. 서브에이전트가 아니라 컨트롤러가 사용자와 함께 진행한다.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-21-word-lookup-design.md` (결과 기록)

- [ ] **Step 1: 기기에 설치**

`WordFinder/Config/Team.xcconfig` 에 `DEVELOPMENT_TEAM` 이 채워져 있어야 한다.

```bash
export PATH="/opt/homebrew/bin:$PATH"; xcodegen generate
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder -destination 'id=<기기 UDID>' -configuration Debug -allowProvisioningUpdates build
xcrun devicectl device install app --device <CoreDevice ID> <빌드된 .app 경로>
xcrun devicectl device process launch --device <CoreDevice ID> --terminate-existing com.wordfinder.app
```

UDID 는 `xcodebuild -showdestinations`, CoreDevice ID 는 `xcrun devicectl list devices` 로 찾는다.

- [ ] **Step 2: 스펙 §10 항목을 사용자와 확인**

1. 단어를 누르면 스피너가 뜨고, **3초 안에** 성공 화면 또는 Apple 사전이 뜨는가
2. 성공 화면: 발음기호 없는 단어에서 줄이 생략되는가, 품사가 여러 개면 반복되는가, "Show all" 이 동작하는가 (예: `run`)
3. 실패 화면: 안내 한 줄이 Apple 사전 위에 뜨는가
4. **Apple 사전의 "완료" 버튼** — 누르면 우리 시트까지 닫히고 카메라가 `idle` 로 돌아오는가. 닫히지 않거나 상태가 어긋나면, 끼워 넣지 않고 우리 시트를 닫은 뒤 Apple 사전을 따로 띄우는 방식으로 바꾸는 후속 작업이 필요하다
5. 비행기 모드에서 Apple 사전으로 뜻이 나오는가

2026-09-21 기준 dictionaryapi.dev 는 흔한 단어도 약 20초가 걸리므로 **대부분 Apple 사전으로 넘어가는 것이 정상이다.** 성공 화면을 보려면 API 가 회복된 뒤이거나 우연히 빨리 응답한 경우다.

- [ ] **Step 3: 결과를 스펙에 기록**

스펙 끝에 `## 12. 실기기 검증 결과` 를 추가하고 위 다섯 항목의 결과와 확인하지 못한 것을 적는다.

- [ ] **Step 4: 커밋과 PR**

```bash
git add docs/superpowers/specs/2026-09-21-word-lookup-design.md
git commit -m "docs: record on-device results for word lookup"
git push -u origin feat/word-lookup
gh pr create --base feat/camera-device-tuning --head feat/word-lookup
```

PR 은 카메라 튜닝 PR 위에 쌓인다. 본문에 **`DictEntry` 계약 변경(`Meaning.synonyms` 추가)이 들어 있어 협업자 확인이 필요하다**는 것을 맨 앞에 적는다.
