# WordFinder — 카메라 영영사전 앱 개발 계획 (v3 — iOS 네이티브 확정)

작성일: 2026-08-18
원본: LensDict 기획서 v2 (2026-07-20)를 iOS 전용·네이티브 Swift 전환 결정에 맞춰 갱신

---

## 0. 확정된 전제 (변경됨)

| 항목 | 결정 | 비고 |
|---|---|---|
| 플랫폼 | **iOS 전용 출시** | Android 미계획. 향후 필요 시 별도 검토 |
| 프레임워크 | **네이티브 Swift / SwiftUI** | 원안의 "Bare RN → 추후 네이티브 전환" 2단계 계획을 폐기하고 처음부터 네이티브로 진행 |
| 앱 이름 | **WordFinder** | (원안 가칭 LensDict, 파일명 WordScan에서 확정) |
| 사전 소스 | dictionaryapi.dev 主 → Merriam-Webster Learner's 補 | 원안 유지 (서버 사이드라 스택 전환 영향 없음) |
| 언어 | 영어 → 영어 (영영사전) 우선 | 원안 유지 |

### 왜 bare RN 대신 네이티브인가
원 기획서 5장의 핵심 전제는 "지금 RN으로 만들고 나중에 네이티브로 간다"였고, 그 이유로 리스크의 상당 부분(Android 검증 지연, New Architecture에서 vision-camera·ML Kit·op-sqlite 동시 호환성 확보)이 존재했습니다. **iOS만 낼 것이 확정되면서 이 2단계 계획의 전제 자체(=크로스플랫폼 중간 단계 확보)가 사라졌습니다.** 처음부터 SwiftUI로 가면:
- 나중에 버려질 RN UI 코드가 없음 — 지금 만드는 게 곧 최종 결과물
- 카메라(AVFoundation)·OCR(Vision framework)·로컬 DB(SwiftData)가 모두 Apple 1st-party라 New Arch 호환성 지뢰 자체가 존재하지 않음
- 원 기획서의 핵심 설계 원칙("비즈니스 로직은 서버에 둔다", "API 계약을 v1으로 고정한다")은 오히려 지금 그대로 유효 — Cloud Functions·DictEntry 스키마·Firestore 캐시는 변경 없음

---

## 1. 제품 개요 (원안 유지)

| 항목 | 내용 |
|---|---|
| 한 줄 정의 | 모르는 영단어를 카메라로 찍으면 즉시 뜻·예문·발음을 보여주는 영영사전 앱 |
| 핵심 가치 | 타이핑 없이 3초 안에 뜻 확인 (원서·논문·표지판·메뉴판) |
| 타깃 | 영어 원서/전공서를 읽는 중상급 학습자, 유학생, 해외 체류자 |
| 플랫폼 | **iOS** |
| 차별점 | 번역기가 아니라 사전. 단어 단위로 뜻·품사·예문·발음을 보여주고, 문맥 문장과 함께 학습 히스토리에 쌓임 |

---

## 2. 사용자 플로우 (v4 — 3탭 구조로 확정)

홈 화면 없이 **카메라 화면이 곧 앱의 시작 화면**입니다. 탭바는 **카메라 / 히스토리 / 설정** 3개로 확정.

```
앱 실행 → [카메라] 화면 (기본 시작 화면)
  ├ 화면 중앙 고정 텍스트 박스 가이드 (가로: 화면 절반, 세로: 10pt 텍스트 1줄 비율)
  │  바깥 영역은 블러(비네팅) 처리 — 사용자가 폰을 움직여 박스 안에 텍스트를 맞춤
  ├ 박스 안 텍스트 인식 (온디바이스, Vision framework)
  └→ 카메라 화면 위 바텀시트/오버레이로 결과 표시
        정의/품사/발음기호/TTS/예문 — 화면 전환 없음
        └ 자동 히스토리 저장

[히스토리] 탭 — 검색한 단어 리스트 + 검색 기능
[설정] 탭 — 테마 선택(라이트/다크), 캐시 삭제, 사전 출처 고지 등
```

> **v3 대비 변경**: 원안의 "드래그로 크기/위치 조절 가능한 크롭 오버레이"(F2)는 **고정 크기 텍스트 박스 가이드**로 대체되었습니다. 박스 크기는 사용자가 조절하지 않고, 카메라를 움직여 맞추는 방식입니다. "인식 결과"와 "단어 상세"는 더 이상 별도 화면이 아니라 **카메라 화면 위 바텀시트**로 통합되었고, "홈"과 "즐겨찾기" 탭은 이번 구조에서 제외되었습니다 (즐겨찾기 기능이 필요하면 추후 히스토리 내 기능으로 재검토).
>
> 이 방식은 원래 0주차 PoC에서 검토하기로 한 "`DataScannerViewController` 라이브 스캔" 방향과 잘 맞습니다 — 고정 슬릿 안의 텍스트를 실시간 인식하는 UX이므로, PoC에서 `DataScannerViewController` vs 수동 `AVFoundation+Vision` 파이프라인 비교 시 이 고정 박스 형태를 기준으로 검증하세요.

---

## 3. 기능 명세 (원안 유지)

### 3.1 MVP (v1.0)
| # | 기능 | 상세 |
|---|---|---|
| F1 | 카메라 촬영 | 실시간 프리뷰, 플래시, 탭 투 포커스 |
| F2 | 촬영 범위 설정 | **고정 크기 텍스트 박스 가이드**(가로: 화면 절반, 세로: 10pt 텍스트 1줄 비율), 박스 밖은 블러 처리. 사용자가 폰을 움직여 텍스트를 박스에 맞추는 방식(크기 조절 없음) → 박스 내부만 OCR |
| F3 | OCR 인식 | 온디바이스, 라틴 문자. 결과 텍스트 편집 가능 |
| F4 | 단어 토큰화 | 단어 분리, 구두점 제거, 표제어 추정(lemmatize) — **서버(Cloud Functions)에서 처리** |
| F5 | 사전 검색 | 정의(다의어 전부), 품사, 발음기호, 예문 |
| F6 | 발음 재생 | 사전 오디오 URL 우선, 없으면 TTS(AVSpeechSynthesizer) |
| F7 | 히스토리 | 검색 시각·크롭 썸네일·문맥 문장, 날짜별 그룹, 검색, 삭제 |
| F8 | 즐겨찾기 | **보류** — v3까지는 별도 탭이었으나, v4 3탭 구조(카메라/히스토리/설정)에서 제외됨. 필요 시 히스토리 내 기능으로 재검토 |
| F9 | 오프라인 캐시 | 조회한 단어는 로컬 DB(SwiftData)에서 즉시 재조회 |

### 3.2 v1.1 이후 / 3.3 비범위
원안과 동일 (SRS 복습, 갤러리 이미지 인식, 위젯/공유 익스텐션, 클라우드 백업 / 전문 번역·AR·소셜 제외)

---

## 4. 기술 스택 (전면 재작성 — 네이티브)

| 영역 | 선택 | 비고 |
|---|---|---|
| 프레임워크 | **SwiftUI**, 최소 지원 **iOS 17** | UIKit 불필요. SwiftData 사용을 위해 iOS 17+ 권장 |
| 언어 | Swift 5.10+ | — |
| 네비게이션 | SwiftUI `NavigationStack` + `TabView` | React Navigation 대체 |
| 카메라 | `AVFoundation` (`AVCaptureSession`) 또는 `VisionKit DataScannerViewController` | 0주차 PoC로 결정 |
| **OCR** | **Vision framework (`VNRecognizeTextRequest`)** | 온디바이스·무료·오프라인·Apple 1st-party. ML Kit 대체 불필요, New Arch 호환성 이슈 자체가 없음 |
| 크롭 | `Core Graphics` / `CIImage` crop | react-native-image-editor 대체 |
| 이미지 저장/썸네일 | `FileManager` + `CIImage` 리사이즈 | react-native-fs 대체 |
| 로컬 DB | **SwiftData** (iOS 17+) | op-sqlite+Drizzle 대체. 최소 OS를 iOS 16 이하로 낮춰야 하면 `GRDB.swift`로 대체 검토 |
| 설정 저장 | `@AppStorage` / `UserDefaults` | react-native-mmkv 대체 |
| 상태관리 | SwiftUI 자체 (`@Observable`, `@State`, `@Environment`) | Zustand+TanStack Query 불필요 |
| 네트워킹 | `URLSession` + `async/await` | TanStack Query 대체 |
| TTS | `AVSpeechSynthesizer` | expo-speech/react-native-tts 대체 |
| 권한 | `Info.plist` (`NSCameraUsageDescription`) + `AVCaptureDevice` 권한 API | react-native-permissions 대체 |
| 서버 | **Firebase Cloud Functions (2nd gen, TypeScript) — 변경 없음** | 사전 API 프록시. 원안 그대로 재사용 |
| 서버 캐시 | **Firestore `dictCache` 컬렉션 — 변경 없음** | TTL 30일 |
| 운영 | Firebase iOS SDK (Crashlytics · Analytics · Remote Config) | — |
| 빌드/배포 | Xcode, 이후 Fastlane + TestFlight | EAS 불필요 |

### 스택 전환에 따른 실무 메모
- **원 기획서 5장("네이티브 전환을 전제한 아키텍처")의 원칙 1·2는 그대로 유효합니다**: 단어 토큰화·표제어 추정·다중 사전 소스 병합은 여전히 Cloud Functions에 둡니다. 클라이언트가 Swift가 되어도 "서버가 완성된 결과를 주고 앱은 얇은 클라이언트로 동작" 원칙은 동일하게 이득입니다 (서버 로직을 다시 짤 필요가 없으므로).
- 원칙 3("RN 단계에서 UI에 과투자하지 않는다")은 더 이상 적용되지 않습니다 — 처음부터 최종 UI를 만드는 것이므로 디자인에 정상적으로 투자하면 됩니다.
- SwiftData는 iOS 17 미만을 지원하지 않습니다. 타깃 사용자(원서/논문 읽는 학습자)의 기기 최신성을 고려하면 무리 없는 선택이지만, 스토어 등록 시 최소 OS 버전 정책을 한 번 더 확인하세요.

---

## 5. 사전 데이터 전략 (원안 유지 — 서버 사이드라 무변경)

폴백 체인, 통일 스키마(`DictEntry`), 라이선스 리스크(dictionaryapi.dev의 CC BY-SA 출처 표기, MW 무료키 비상업 조건) 모두 원 기획서 6장 그대로 적용됩니다. 이 부분이 원안에서 가장 잘 설계된 부분이며 스택 전환의 영향을 받지 않습니다.

`DictEntry` 타입은 Swift에서는 `Codable` 구조체로 그대로 매핑합니다:

```swift
struct DictEntry: Codable {
    let term: String
    let lang: String            // "en"
    let type: EntryType         // "word" | "phrase"
    let phonetic: String?
    let audioUrl: String?
    let meanings: [Meaning]
    let source: DictSource      // "dictionaryapi" | "mw-learners" | "oxford"
    let fetchedAt: Int

    struct Meaning: Codable {
        let partOfSpeech: String
        let definitions: [Definition]
    }
    struct Definition: Codable {
        let definition: String
        let example: String?
        let synonyms: [String]?
    }
    enum EntryType: String, Codable { case word, phrase }
    enum DictSource: String, Codable { case dictionaryapi, mwLearners = "mw-learners", oxford }
}
```

---

## 6. 데이터 모델 (SwiftData로 재작성)

```swift
import SwiftData

@Model
final class DictEntryRecord {
    @Attribute(.unique) var term: String   // 정규화: lowercase, trim
    var lang: String = "en"
    var type: String                       // "word" | "phrase"
    var payloadJSON: String                // DictEntry를 JSON 인코딩해 저장
    var source: String?
    var fetchedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HistoryRecord.entry)
    var historyItems: [HistoryRecord] = []

    init(term: String, type: String, payloadJSON: String, source: String?, fetchedAt: Date) {
        self.term = term; self.type = type
        self.payloadJSON = payloadJSON; self.source = source; self.fetchedAt = fetchedAt
    }
}

@Model
final class HistoryRecord {
    var entry: DictEntryRecord?
    var searchedAt: Date
    var origin: String          // "camera" | "manual"
    var imagePath: String?      // 크롭 썸네일 로컬 경로
    var contextText: String?    // OCR 원문 (문맥 보존)

    init(entry: DictEntryRecord, searchedAt: Date, origin: String, imagePath: String?, contextText: String?) {
        self.entry = entry; self.searchedAt = searchedAt
        self.origin = origin; self.imagePath = imagePath; self.contextText = contextText
    }
}

@Model
final class FavoriteRecord {
    @Attribute(.unique) var entry: DictEntryRecord?
    var note: String?
    var createdAt: Date

    init(entry: DictEntryRecord, note: String?, createdAt: Date) {
        self.entry = entry; self.note = note; self.createdAt = createdAt
    }
}
```

설계 포인트는 원안과 동일: `entries`/`history` 분리로 같은 단어 반복 조회 시 사전 데이터는 1행, 썸네일은 blob이 아닌 파일 경로만 저장(200px 리사이즈, 500장 초과 시 정리), `contextText`가 복습 가치가 가장 큰 필드.

---

## 7. 화면 구성 (v4 — 3탭 구조)

| 화면 | 내용 |
|---|---|
| 카메라 (시작 화면) | 실시간 프리뷰, 고정 텍스트 박스 가이드(가로 화면 절반 × 세로 10pt 텍스트 1줄 비율), 박스 밖 블러 처리. 인식 결과는 이 화면 위 바텀시트로 표시(표제어·발음기호·🔊, 품사별 정의, 예문, 문맥 원문) |
| 히스토리 | 검색한 단어 리스트, 검색 기능 |
| 설정 | **테마 선택(라이트/다크모드)**, TTS 속도/음성, 캐시·히스토리 삭제, 사전 출처 고지, 오픈소스 라이선스 |

탭바: 카메라 / 히스토리 / 설정

---

## 8. 개발 로드맵 (약 9주 — 단일 플랫폼이라 원안 11주보다 단축)

| 주차 | 마일스톤 | 산출물 |
|---|---|---|
| **0** | **기술 검증(PoC)** | ① Vision framework OCR 정확도 측정 (원서 3권 × 조명 3조건) ② `DataScannerViewController` vs `AVFoundation+Vision` 수동 파이프라인 비교 ③ dictionaryapi.dev 단어 30개 조회 → 품질·응답속도·라이선스 확인 |
| 1 | 프로젝트 셋업 | Xcode 프로젝트, SwiftUI 네비게이션 스켈레톤, Firebase iOS SDK 연동, TestFlight 파이프라인 |
| 2–3 | 카메라 + 크롭 + OCR | 촬영→크롭→텍스트 추출 파이프라인 |
| 4 | 인식 결과 화면 | 단어 칩, 텍스트 직접 수정 |
| 5 | **Cloud Functions** | 폴백 체인 + Firestore 캐시 + `DictEntry` 스키마 확정 + OpenAPI 문서 (원안과 동일) |
| 6 | 단어 상세 + 발음 | 오디오 URL / AVSpeechSynthesizer 폴백 |
| 7 | SwiftData 히스토리/즐겨찾기 | 캐시 계층 포함 |
| 8 | 에러·오프라인 처리 + UI 폴리싱 | 인식 실패, 네트워크 없음, 결과 없음, 철자 제안 |
| 9 | 베타 + 스토어 제출 | TestFlight, Crashlytics, 스크린샷, 개인정보처리방침, 사전 출처 고지 |

---

## 9. 주요 리스크 (RN/Android 관련 항목 제거, iOS 고유 리스크로 정리)

| 리스크 | 영향 | 대응 |
|---|---|---|
| dictionaryapi.dev 다운/레이트리밋 | 높음 — 主 소스 | Firestore 캐시 필수, MW 폴백, Remote Config로 즉시 소스 교체 |
| Wiktionary 파생 라이선스(CC BY-SA) 표기 의무 | 중 | 0주차 확인 + 설정 화면 출처 고지 |
| MW 무료키 비상업 조건 | 중 | 수익화 시점 전에 상업 라이선스 협의 |
| OCR 정확도(작은 글씨·저조도) | 높음 | 크롭 확대 유도 UX, 텍스트 수정 기능 필수, 촬영 가이드 |
| 굴절형 처리(running→run) | 중 | 서버에서 표제어 추정, 실패 시 후보 순차 조회 + "혹시 이 단어인가요?" |
| 영영 정의의 난이도 | 중 | MW Learner's 우선 채택, 동의어 함께 노출 |
| iOS 카메라 권한 반려 | 중 | `NSCameraUsageDescription` 목적 구체 기술 |
| SwiftData 최소 iOS 17 요구 | 낮음~중 | 스토어 등록 전 타깃 사용자 기기 분포 확인. 필요시 GRDB.swift로 다운그레이드 |

---

## 10. 다음 단계

**0주차 PoC부터 시작합니다.**
1. Vision framework OCR 인식률 측정 — 실제 원서 3권 × 조명 3조건
2. 카메라 UX 방식 결정 — 수동 크롭 오버레이 vs `DataScannerViewController` 라이브 스캔
3. 사전 데이터 품질·라이선스 확인 — dictionaryapi.dev 30단어(기본어/전문용어/굴절형/고유명사) 조회

디자인은 별도로 Claude Design에 전달할 프롬프트를 작성해 진행합니다.
