# WordFinder

카메라로 모르는 영단어를 스캔하면 영영사전 뜻·발음·예문을 바로 보여주는 iOS 앱.

- 요구사항: **Xcode 16+**, iOS 17+ 시뮬레이터(SwiftData 사용)
- 스택: SwiftUI + SwiftData, 프로젝트 구조는 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 관리
- 기획/기술 계획 전체: [PLAN.md](PLAN.md)
- 디자인 방향(Claude Design 핸드오프 프롬프트): [design_prompt_for_claude_design.md](design_prompt_for_claude_design.md)

## 처음 열 때

`WordFinder.xcodeproj`를 그대로 더블클릭해서 열면 바로 빌드됩니다. 별도 설치 없이 시뮬레이터 실행 가능.

실기기에서 돌리려면 Xcode에서 **Signing & Capabilities → Team**을 본인 Apple ID로 바꿔야 합니다 (지금은 시뮬레이터 전용 서명 상태).

## 프로젝트 구조를 바꿀 때

이 프로젝트는 `.xcodeproj`를 직접 만지지 않고 `project.yml`(XcodeGen 스펙)에서 생성합니다. 새 파일을 Xcode 안에서 추가/삭제하는 정도는 그냥 하시면 되고, 타겟 설정·빌드 세팅·Info.plist 키처럼 구조적인 걸 바꿨다면:

```bash
brew install xcodegen   # 처음 한 번만
xcodegen generate       # project.yml → WordFinder.xcodeproj 재생성
```

## 폴더 구조

```
WordFinder/
├── App/            # @main 진입점
├── Root/           # 탭바(카메라 / 히스토리 / 설정)
├── Features/       # 화면별 View
│   ├── Camera/     # 시작 화면 — 라이브 스캔 + 결과 바텀시트(2단계)
│   ├── History/    # 검색 히스토리
│   └── Settings/   # 테마, 발음, 데이터, 정보
├── Models/         # DictEntry(서버 계약), SwiftData 모델
└── Design/         # 컬러·타이포 토큰 (Claude Design 시스템 반영)
```

## 지금 상태

- 카메라 화면의 실제 촬영/OCR은 아직 placeholder입니다. `CameraView.swift`의 `// TODO` 참고 — Vision framework 기반 OCR 붙이는 게 다음 단계(PLAN.md 0주차 PoC).
- Firebase(사전 API 프록시)는 아직 연동 전입니다.
