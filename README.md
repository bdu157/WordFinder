# WordFinder

카메라로 모르는 영단어를 스캔하면 영영사전 뜻·발음·예문을 바로 보여주는 iOS 앱.

- 요구사항: **Xcode 16+**, iOS 17+ 시뮬레이터(SwiftData 사용)
- 스택: SwiftUI + SwiftData, 프로젝트 구조는 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 관리
- 기획/기술 계획 전체: [PLAN.md](PLAN.md)
- 디자인 방향(Claude Design 핸드오프 프롬프트): [design_prompt_for_claude_design.md](design_prompt_for_claude_design.md)

## 처음 열 때

**`WordFinder.xcodeproj`는 git에 커밋되지 않습니다** — `project.yml`(XcodeGen 스펙)에서 생성되는 결과물입니다. 클론 후:

```bash
brew install xcodegen   # 처음 한 번만
xcodegen generate       # project.yml → WordFinder.xcodeproj 생성
open WordFinder.xcodeproj
```

시뮬레이터 실행은 이걸로 끝입니다.

**실기기**에서 돌리려면 서명 팀 설정이 필요합니다:

```bash
cp WordFinder/Config/Team.xcconfig.example WordFinder/Config/Team.xcconfig
# Team.xcconfig을 열어 DEVELOPMENT_TEAM을 본인 Apple Developer Team ID로 수정
xcodegen generate
```

`Team.xcconfig`는 gitignore되어 있어 각자 자기 Team ID를 넣어도 서로 덮어쓰지 않습니다.

## 프로젝트 구조를 바꿀 때

새 파일을 Xcode 안에서 추가/삭제하는 정도는 그냥 하시면 다음 `xcodegen generate` 때 반영됩니다. 타겟 설정·빌드 세팅·Info.plist 키처럼 구조적인 걸 바꿨다면 `project.yml`을 고치고:

```bash
xcodegen generate       # project.yml → WordFinder.xcodeproj 재생성
```

그 후 커밋 전에 `xcodebuild`로 빌드가 되는지 한 번 확인해주세요 (`.xcodeproj`는 커밋 대상이 아니지만, 그게 정상적으로 생성/빌드되는지는 PR 전에 검증해야 합니다).

## Claude Code로 작업할 때

두 사람 다 Claude Code를 쓴다면 [CLAUDE.md](CLAUDE.md)를 먼저 읽게 하세요 — 빌드 명령, XcodeGen 워크플로, 아키텍처 전제, 현재 placeholder 목록이 정리되어 있습니다.

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
