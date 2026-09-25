import SwiftUI

/// 앱의 시작 화면. 셔터가 아니라 연속 라이브 스캔이며, 가이드 박스 밖은 블러 처리된다.
/// Scan 버튼이 인식의 시작을 통제하고, 박스 안 텍스트가 안정되면 자동으로 확정된다.
/// 설계 근거는 `docs/superpowers/specs/2026-08-19-camera-ocr-design.md`.
struct CameraView: View {
    /// 프리뷰를 얹으려면 구체 타입이 필요하므로 화면이 소유한다.
    /// `ScanViewModel` 은 프로토콜 너머로만 이걸 본다.
    ///
    /// **카메라 구현 교체 지점.** `AVCaptureSession` + Vision 구현으로 바꿀 때는 이 타입,
    /// 아래 `init()` 의 생성, `body` 의 프리뷰 뷰 — 이 파일의 세 곳만 고친다.
    @State private var recognizer: DataScannerRecognizer
    @State private var model: ScanViewModel
    @State private var showsSheet = false
    @State private var detailWord: ScannedWord?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let recognizer = DataScannerRecognizer()
        _recognizer = State(initialValue: recognizer)
        _model = State(initialValue: ScanViewModel(recognizer: recognizer))
    }

    private let guideBoxHeight: CGFloat = 38
    private let guideBoxCornerRadius: CGFloat = 4
    /// 가이드 박스의 세로 중심 (화면 높이 비율). 목업 기준이며, 시트가 `.medium`
    /// 으로 올라와도 가리지 않도록 정중앙을 피해 두었다.
    private let guideBoxCenterY: CGFloat = 0.239
    /// 가이드 박스 바깥 블러 레이어의 불투명도. `.ultraThinMaterial` 이 이미 가장 얇은
    /// 시스템 재질이라, 더 비치게 하려면 레이어 자체를 옅게 하는 수밖에 없다.
    /// 1이면 주변이 뿌옇게 가려져서 찾을 단어를 박스로 가져오기 어렵다는 실기기 피드백이
    /// 있었다. 낮출수록 주변이 또렷해지는 대신 박스가 덜 도드라진다.
    private let outsideBlurOpacity: Double = 0.7

    var body: some View {
        GeometryReader { geo in
            let guideWidth = geo.size.width / 2
            let guideRect = CGRect(
                x: (geo.size.width - guideWidth) / 2,
                y: geo.size.height * guideBoxCenterY - guideBoxHeight / 2,
                width: guideWidth,
                height: guideBoxHeight
            )

            // `guideRect` 는 안전 영역 안쪽 좌표다. 카메라 프리뷰와 블러 마스크는
            // `.ignoresSafeArea()` 로 화면 전체에 깔리므로 원점이 안전 영역 인셋만큼
            // 어긋나 있다. 그 두 레이어에는 화면 전체 좌표로 옮긴 사각형을 넘긴다.
            // 이걸 빠뜨리면 인식 영역이 브래킷보다 상단 인셋만큼 위에 잡혀서, 사용자가
            // 브래킷 안에 맞춘 단어가 아니라 그 위의 띠를 읽는다.
            let fullScreenGuideRect = guideRect.offsetBy(
                dx: geo.safeAreaInsets.leading,
                dy: geo.safeAreaInsets.top
            )

            ZStack {
                ScannerViewRepresentable(
                    recognizer: recognizer,
                    regionOfInterest: fullScreenGuideRect
                )
                .ignoresSafeArea()

                GuideMaskShape(holeRect: fullScreenGuideRect, cornerRadius: guideBoxCornerRadius)
                    .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
                    .opacity(outsideBlurOpacity)
                    .ignoresSafeArea()

                CornerBracketsShape()
                    .stroke(bracketColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: guideRect.width, height: guideRect.height)
                    .position(x: guideRect.midX, y: guideRect.midY)

                captionView
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: guideRect.maxY + 28)

                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .padding(.top, 8)
            }
            .sheet(isPresented: $showsSheet, onDismiss: { model.dismissSheet() }) {
                sheetContent
            }
            .onChange(of: model.state) { _, newState in
                if case .settled = newState { showsSheet = true }
            }
            .task(id: isScanning) {
                // **필수** — `ScanViewModel.tick()` 을 굴리지 않으면 타임아웃이 죽는다.
                // `DataScannerViewController` 의 델리게이트는 이벤트 단위라, 박스 안에
                // 아무것도 없으면 콜백이 아예 오지 않아 `ingest` 가 호출되지 않는다.
                // 빈 벽을 비추는 경우가 정확히 타임아웃이 존재하는 이유다.
                guard isScanning else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    model.tick()
                }
            }
            // 화면을 벗어나거나(다른 탭) 앱이 백그라운드로 가면 스캔을 멈춘다. 안 그러면
            // 히스토리 탭을 보는 동안에도 카메라가 켜져 있다. `tapCancel()` 은 스캔 중이
            // 아닐 때는 아무것도 하지 않으므로 어느 상태에서 불러도 안전하다.
            // `.inactive` (제어 센터를 내리는 등 일시적 상태)에서는 멈추지 않는다.
            .onDisappear { model.tapCancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.tapCancel() }
            }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let detailWord {
            WordDetailSheet(detail: CameraMock.detail)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .onDisappear { self.detailWord = nil }
        } else if case .settled(let words) = model.state {
            WordListSheet(words: words) { word in
                detailWord = word
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var isScanning: Bool {
        if case .scanning = model.state { return true }
        return false
    }

    private var bracketColor: Color {
        if case .settled = model.state { return Color.wfAccent }
        return .white.opacity(0.9)
    }

    @ViewBuilder
    private var captionView: some View {
        switch model.state {
        case .idle(let message):
            VStack(spacing: 4) {
                Text(message ?? "Line up a word inside the box")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                if message == nil {
                    Text("Tap Scan when it's in frame")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
        case .scanning(let preview):
            Text(preview ?? "Looking for text…")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .padding(.horizontal, 32)
        case .settled(let words):
            Text("\(words.count) words found in frame")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: 0x7FD98F))
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                // TODO: toggle torch via AVCaptureDevice once the real camera session exists
            } label: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.5), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var statusLabel: String {
        if case .scanning = model.state { return "Scanning · Offline" }
        return "Ready · Offline"
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch model.state {
        case .idle:
            scanButton(title: "Scan", action: model.tapScan)
        case .scanning:
            scanButton(title: "Cancel", action: model.tapCancel)
        case .settled:
            EmptyView()
        }
    }

    private func scanButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor, in: Capsule())
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
    }
}

/// Cuts a rounded-rect hole out of a full-screen rect using the even-odd fill rule,
/// so a material fill applied with this shape blurs everything except the hole.
private struct GuideMaskShape: Shape {
    let holeRect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: holeRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

/// Four L-shaped corner brackets around a rect, like a camera focus reticle.
private struct CornerBracketsShape: Shape {
    var bracketLength: CGFloat = 16
    var outset: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: -outset, dy: -outset)
        var path = Path()

        path.move(to: CGPoint(x: r.minX, y: r.minY + bracketLength))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.minX + bracketLength, y: r.minY))

        path.move(to: CGPoint(x: r.maxX - bracketLength, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + bracketLength))

        path.move(to: CGPoint(x: r.maxX, y: r.maxY - bracketLength))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX - bracketLength, y: r.maxY))

        path.move(to: CGPoint(x: r.minX + bracketLength, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - bracketLength))

        return path
    }
}

#Preview {
    CameraView()
}
