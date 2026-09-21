# 단어 상세 — 사전 조회 1단계 설계

작성일: 2026-09-21 · 선행: `2026-08-19-camera-ocr-design.md` (카메라 OCR, Task 1~7)

## 1. 범위

단어 목록에서 단어를 누르면 **그 단어의 실제 영영 정의·품사·발음기호·예문**이 상세 시트에 뜨게 한다. 지금은 어떤 단어를 눌러도 목업 `resilient`가 뜬다.

상세 화면 작업은 세 단계로 나눈다. 이 문서는 1단계만 다룬다.

```
1. 사전 조회 (뜻·품사·발음기호·예문)   ← 이 문서
2. 발음 재생 🔊                        ← 1이 저장하는 audioUrl 사용
3. 히스토리 저장                       ← 1의 DictEntry 를 SwiftData 에 저장
```

### 범위 밖

- 발음 재생 (2단계), 히스토리 저장 (3단계)
- "Captured Context" — 실제로 찍은 문장 보여주기
- 서버(Cloud Functions) — §11에서 다룸
- 표제어 추정 (`running` → `run`) — 서버 몫 (PLAN.md F4)

## 2. 배경 — 주 사전 소스가 사실상 내려가 있다

PLAN.md는 dictionaryapi.dev를 주 소스로, 서버가 앞에서 캐시하고 Merriam-Webster로 폴백하는 구조를 정했다. 서버는 아직 없다. 2026-09-21에 dictionaryapi.dev를 직접 측정했다.

| 단어 | 응답 시간 | 결과 |
|---|---|---|
| resilient, flexible, running, absorbed | 약 20초 | 200 |
| shocks, urban, 없는 단어(여러 번 재시도) | 약 20초 | **522** |

같은 시각 GitHub API는 0.3초에 응답해 측정 환경 문제가 아니다. 522는 Cloudflare가 원본 서버에 연결하지 못했다는 뜻이다. 성공한 단어는 모두 흔한 단어라, **원본은 내려가 있고 Cloudflare에 캐시돼 있던 단어만 20초 뒤 옛 캐시로 응답**하는 것으로 보인다. PLAN.md §9가 1순위로 꼽은 위험이 실제로 일어난 상태다.

그래서 이 단계는 dictionaryapi.dev를 믿지 않는 것을 전제로 설계한다.

## 3. 결정 사항

| 항목 | 결정 |
|---|---|
| 데이터 소스 | 앱이 dictionaryapi.dev를 직접 호출 (임시). 서버는 이후 단계 |
| 교체 가능성 | `DictionaryService` 프로토콜 뒤에 격리 — 서버가 생기면 구현체만 교체 |
| 제한 시간 | **요청 전체 3초** |
| 실패 시 | **Apple 내장 영영사전으로 자동 전환** (`UIReferenceLibraryViewController`) + 안내 한 줄 |
| 화면 데이터 형식 | 기존 `DictEntry` (서버 계약) — 앱 직접 호출이든 서버든 화면은 같은 타입을 받는다 |
| 계약 변경 | `DictEntry.Meaning` 에 선택 항목 `synonyms` 추가 (§8) |
| 뜻 개수 | 품사당 3개, 넘으면 "Show all" |

## 4. 구조

```
WordListSheet ──(누른 단어)──► WordLookupView
                                  ├─ loading  → 단어 + 스피너
                                  ├─ loaded   → WordDetailSheet(entry: DictEntry)
                                  └─ fallback → 안내 한 줄 + SystemDictionaryView
                                        │
                              WordLookupModel  @MainActor @Observable
                                        │
                              DictionaryService (프로토콜)   ◄── 서버로 교체할 자리
                                        └─ DictionaryAPIClient
                                              ├─ URLSession (3초)
                                              ├─ interpret(status:data:)   순수
                                              └─ DictionaryAPIMapper        순수
```

| 조각 | 하는 일 | 의존 |
|---|---|---|
| `DictionaryService` | 단어 → `DictEntry`, 실패는 `DictionaryError` | 프로토콜 |
| `DictionaryAPIClient` | 네트워크 호출. 상태 코드 해석과 변환은 순수 함수로 분리 | URLSession |
| `DictionaryAPIMapper` | dictionaryapi.dev JSON → `DictEntry` | 없음 (순수) |
| `WordLookupModel` | 조회를 돌리고 화면 상태를 관리 | `DictionaryService` |
| `WordLookupView` | 상태별로 세 화면 중 하나를 보여줌 | 모델 |
| `WordDetailSheet` | 성공 화면 (기존 레이아웃) | `DictEntry` |
| `SystemDictionaryView` | Apple 사전을 SwiftUI에 얹음 | UIKit |

`WordLookupModel` 은 네트워크도 UIKit도 모른다. 프로토콜 너머의 가짜로 상태 전이를 전부 검증한다 — 카메라의 `ScanViewModel` 과 같은 방식이다.

## 5. 화면

화면 배치(Claude Design 레이아웃)는 그대로 둔다. 가짜 데이터를 전제로 만든 부분만 바꾼다.

| 부분 | 지금 | 바뀐 뒤 | 이유 |
|---|---|---|---|
| 불러오는 중 | 없음 | 누른 단어 + 스피너 | 누른 즉시 반응이 보여야 한다 |
| 발음기호 | 항상 표시 | 없으면 줄 생략 | `resilient` 는 발음기호가 아예 없다 |
| 품사 | 1개만 | 품사마다 반복 | `running` 은 품사가 5개 |
| 뜻 개수 | 전부 | 품사당 3개 + "Show all N" | `running` 의 동사 뜻은 34개 |
| 동의어 | 단어 전체에 한 줄 | 품사마다 한 줄 (있을 때만) | 동의어는 대부분 품사 단위로 온다 |
| 🔊 버튼 | 눌러도 아무 일 없음 | 숨김 | 2단계에서 되살린다 |
| Captured Context 카드 | 가짜 문장 | 제거 | 범위 밖. 진짜 뜻 옆의 가짜 문장은 오해를 부른다 |
| 하단 "Saved to History · …" | 저장 안 되는데 문구만 있음 | `Definitions: dictionaryapi.dev (CC BY-SA)` | 거짓 문구 제거. 출처 표기는 라이선스 의무. 3단계에서 저장 문구를 되살린다 |
| "Keep scanning" | 있음 | 유지 | — |

**실패 화면**은 Apple 사전 위에 안내 한 줄을 둔다. 없으면 사용자는 화면 모양이 갑자기 달라진 이유를 모른다 (§7).

`WordDetailPreview`, `DefinitionPreview`, `CameraMock.detail` 은 쓰이지 않게 되므로 삭제한다. `CameraMock.recognizedWords` 는 `WordListSheet` 프리뷰가 계속 쓴다.

## 6. dictionaryapi.dev 응답 → `DictEntry` 변환

실제 응답(`WordFinderTests/Fixtures/`)을 보고 정한 규칙이다.

| 응답의 모양 | 규칙 |
|---|---|
| 최상위가 **항목 배열** — 동형이의어면 항목이 여러 개 | 전부 합친다. **같은 품사는 하나로** 묶고 처음 나온 순서를 유지한다 |
| 발음기호가 `phonetic` 에 없고 `phonetics[].text` 에만 있기도 하다 | `phonetic` → `phonetics[].text` 순으로 비어 있지 않은 첫 값. 둘 다 없으면 `nil` |
| 음성 파일이 `phonetics[]` 일부에만 있다 (`running` 은 두 번째에만) | 비어 있지 않은 첫 `audio` 를 `audioUrl` 로 |
| 동의어가 뜻 단위와 품사 단위 양쪽에 있다 | 뜻 단위 → `Definition.synonyms`, 품사 단위 → `Meaning.synonyms`. 각각 중복 제거, 비면 `nil` |
| `term` | 첫 항목의 `word` |
| `type` | 공백이 있으면 `phrase`, 없으면 `word` |
| `source` | `.dictionaryapi` |
| `fetchedAt` | **1970년 기준 초 단위 정수**. 지금까지 단위가 정해져 있지 않았다 — 이번에 확정하고 `DictEntry` 에 주석으로 남긴다 |
| `lang` | `"en"` |

두 픽스처(`resilient`, `running`)는 모두 항목이 하나라 **같은 품사 합치기는 실제 응답으로 검증할 수 없다.** 이 규칙만 손으로 만든 작은 JSON으로 검증하고, 테스트에 합성 데이터임을 밝힌다.

## 7. 실패 처리

모든 실패는 Apple 사전으로 가지만 안내 문구는 원인에 따라 둘로 나눈다.

| 상황 | `DictionaryError` | 안내 문구 |
|---|---|---|
| HTTP 404 — 온라인 사전에 없는 단어 | `.notFound` | `Not in the online dictionary — showing the iOS Dictionary` |
| 3초 초과, 522, 5xx, 네트워크 끊김, 응답 해석 실패 | `.unavailable` | `Online dictionary didn't respond — showing the iOS Dictionary` |

**3초는 요청 전체 시간이다.** `URLSessionConfiguration` 의 `timeoutIntervalForRequest` 는 "데이터가 안 오는 공백" 기준이라, 조금씩 흘려보내는 서버에서는 3초를 넘길 수 있다. `timeoutIntervalForResource` 도 3초로 묶는다.

**Apple 사전은 오프라인에서도 동작한다.** 비행기 모드에서도 뜻이 나온다. 다만 영어 사전을 기기에 내려받지 않은 사용자에게는 "정의 없음"과 사전 관리 버튼이 뜬다 — iOS 동작이라 바꿀 수 없다.

## 8. 계약 변경 — `DictEntry.Meaning.synonyms`

dictionaryapi.dev에서 동의어는 대부분 **품사 단위**로 온다. `resilient` 의 `bendable`, `flexible`, `strong` 이 그렇다. `DictEntry` 에는 동의어 자리가 뜻 단위(`Definition.synonyms`)에만 있어서, 지금 계약대로면 이 동의어가 전부 버려진다.

`DictEntry.Meaning` 에 `let synonyms: [String]?` 를 추가한다.

- **선택 항목**이라 이 필드가 없는 JSON도 그대로 읽힌다. 아직 만들어지지 않은 서버가 이 필드를 몰라도 깨지지 않는다.
- 3단계에서 `DictEntryRecord.payloadJSON` 에 이 JSON을 **기기에 저장**한다. 계약이 바뀌어도 저장된 데이터가 읽혀야 하므로, **동의어 항목이 없는 JSON의 디코딩을 테스트로 고정**한다.
- `DictEntry` 는 협업자와 약속한 공유 계약이다 (`WordFinder/Models/` 는 공유 영역). **PR에서 협업자 확인을 받는다.**

## 9. 테스트 전략

네트워크 없이 검증되는 부분을 최대한 떼어낸다.

| 대상 | 방법 |
|---|---|
| `DictEntry` 호환성 | `Meaning.synonyms` 가 없는 JSON 디코딩, 있는 JSON 왕복 |
| `DictionaryAPIMapper` | **실제 응답 픽스처** `resilient` · `running` + 같은 품사 합치기용 합성 JSON |
| `DictionaryAPIClient.interpret(status:data:)` | 200 → 변환, 404 → `.notFound`, 522·500 → `.unavailable`, 깨진 JSON → `.unavailable`. 순수 함수라 네트워크 불필요 |
| `WordLookupModel` | 가짜 `DictionaryService` 로 로딩 → 성공 / 없음 / 무응답 |
| 실제 호출, Apple 사전, 화면 | 실기기 (§10) |

404 응답 본문은 녹화하지 못했다 (§2 — 없는 단어는 모두 522). `interpret` 는 404를 **상태 코드만으로** 판단하므로 본문이 필요 없다.

픽스처는 테스트 소스 파일 위치(`#filePath`)를 기준으로 읽는다. 시뮬레이터에서 동작함을 확인했다.

## 10. 실기기 확인 항목

- 단어를 누르면 스피너가 뜨고, 3초 안에 성공 화면 또는 Apple 사전이 뜨는가
- Apple 사전의 **"완료" 버튼**을 누르면 우리 시트까지 닫히고 카메라가 `idle` 로 돌아오는가. Apple 화면을 우리 시트 안에 끼워 넣는 방식이라 시뮬레이터로는 확신할 수 없다. 닫히지 않거나 상태가 어긋나면, 끼워 넣지 않고 우리 시트를 닫은 뒤 Apple 사전을 따로 띄우는 방식으로 바꾼다
- 비행기 모드에서 Apple 사전으로 뜻이 나오는가
- 뜻이 많은 단어(예: `run`)에서 "Show all" 이 동작하는가

## 11. 서버(A)로 넘어갈 때

이 단계는 서버가 생길 때 버려지지 않도록 설계했다.

- 서버용 `DictionaryService` 구현체를 새로 만들고 `WordLookupModel` 에 넣는 구현체만 바꾼다. 화면은 그대로다.
- `DictionaryAPIMapper` 의 변환 규칙(§6)은 서버 쪽 구현의 참고가 된다. 같은 규칙으로 `DictEntry` 를 만들면 화면이 똑같이 보인다.
- Apple 사전 폴백은 서버가 있어도 남긴다 — 비행기 모드에서 뜻을 보여주는 유일한 방법이다.

서버에 필요한 준비(Firebase 프로젝트, Cloud Functions 배포용 Blaze 요금제, Merriam-Webster API 키, 서버 담당)는 아직 정해지지 않았다.
