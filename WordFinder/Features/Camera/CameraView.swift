import SwiftUI

/// Start screen of the app — a continuous live-scan viewfinder, not a shutter-based
/// camera. Everything outside a fixed guide box is dimmed/blurred; text that sits in
/// the box is recognized automatically. See design_prompt's Claude Design project,
/// section "2a" (3탭 구조) for the source mockups this view matches.
///
/// The capture session itself is a placeholder — that's the Week 0 PoC
/// (AVFoundation + Vision framework vs. VisionKit DataScannerViewController,
/// see PLAN.md §2, §8). Tap anywhere to simulate a successful scan.
struct CameraView: View {
    @State private var scanState: ScanState = .idle
    @State private var sheetStage: SheetStage?

    private let guideBoxHeight: CGFloat = 38
    private let guideBoxCornerRadius: CGFloat = 4
    /// Vertical center of the guide box as a fraction of screen height (matches the
    /// design mockups: box top 190pt / frame height 874pt ≈ center at 0.239). Kept off
    /// dead-center so the sheet's `.medium` detent doesn't cover it when it rises.
    private let guideBoxCenterY: CGFloat = 0.239

    enum ScanState {
        case idle
        case recognized
    }

    enum SheetStage: Identifiable {
        case wordList
        case detail(ScannedWord)

        var id: String {
            switch self {
            case .wordList: return "wordList"
            case .detail(let word): return "detail-\(word.id)"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let guideWidth = geo.size.width / 2
            let guideRect = CGRect(
                x: (geo.size.width - guideWidth) / 2,
                y: geo.size.height * guideBoxCenterY - guideBoxHeight / 2,
                width: guideWidth,
                height: guideBoxHeight
            )

            ZStack {
                scannedBackground
                    .ignoresSafeArea()

                GuideMaskShape(holeRect: guideRect, cornerRadius: guideBoxCornerRadius)
                    .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
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
                }
                .padding(.top, 8)
            }
            .contentShape(Rectangle())
            .onTapGesture { simulateRecognition() }
            .sheet(item: $sheetStage, onDismiss: { scanState = .idle }) { stage in
                switch stage {
                case .wordList:
                    WordListSheet(words: CameraMock.recognizedWords) { word in
                        sheetStage = .detail(word)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                case .detail:
                    WordDetailSheet(detail: CameraMock.detail)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var bracketColor: Color {
        scanState == .idle ? .white.opacity(0.9) : Color.wfAccent
    }

    @ViewBuilder
    private var captionView: some View {
        switch scanState {
        case .idle:
            VStack(spacing: 4) {
                Text("Line up a word inside the box")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                Text("Move your phone to scan continuously")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .recognized:
            Text("\(CameraMock.recognizedWords.count) words found in frame")
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
                Text("Scanning · Offline")
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

    /// TODO: Replace with an AVFoundation `AVCaptureSession` preview layer (Week 0 PoC).
    /// The blur mechanism (material fill with a hole cut out) is production-shaped —
    /// only this background layer is a stand-in.
    private var scannedBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xD8CFBC), Color(hex: 0xC9BFA9), Color(hex: 0xA9A08C)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 13) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x1E1A14).opacity(0.62))
                        .frame(height: 9)
                        .padding(.trailing, CGFloat((index % 4) * 24))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 130)
        }
    }

    private func simulateRecognition() {
        guard scanState == .idle else { return }
        scanState = .recognized
        sheetStage = .wordList
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
