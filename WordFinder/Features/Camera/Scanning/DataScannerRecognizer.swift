import Foundation
import VisionKit

/// `TextRecognizer` 의 VisionKit 구현.
///
/// 카메라 세션·초점·연속 인식·프레임 관리가 전부 내장이라 우리가 붙일 코드는
/// 관심 영역 지정과 결과 수신뿐이다. 대신 픽셀 버퍼에 접근할 수 없어 작은 글씨
/// 확대나 대비 보정 같은 전처리는 넣을 수 없다. 인식률이 부족하면
/// `AVCaptureSession` + `VNRecognizeTextRequest` 구현체로 교체한다 (PLAN.md §8).
@MainActor
final class DataScannerRecognizer: NSObject, TextRecognizer {
    var onText: ((String?) -> Void)?

    /// 뷰 좌표계의 가이드 박스. `startScanning()` 호출 전에 설정한다.
    var regionOfInterest: CGRect?

    let controller: DataScannerViewController

    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    override init() {
        controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: false,          // 우리 오버레이를 쓴다
            isHighlightingEnabled: false       // 브래킷을 우리가 그린다
        )
        super.init()
        controller.delegate = self
    }

    func startScanning() throws {
        guard DataScannerViewController.isSupported else {
            throw RecognizerError.unsupportedDevice
        }
        controller.regionOfInterest = regionOfInterest
        do {
            try controller.startScanning()
        } catch DataScannerViewController.ScanningUnavailable.unsupported {
            throw RecognizerError.unsupportedDevice
        } catch DataScannerViewController.ScanningUnavailable.cameraRestricted {
            // 권한 거부와 Screen Time 제한이 모두 여기로 온다. 둘 다 설정에서 푼다.
            throw RecognizerError.permissionDenied
        } catch {
            // 그 밖의 실패는 그대로 흘려보낸다. `ScanViewModel` 의 catch-all 이
            // "다시 시도" 안내를 띄운다 — 하드웨어 미지원으로 오인하지 않게.
            throw error
        }
    }

    func stopScanning() {
        controller.stopScanning()
    }

    /// 박스 안 항목들을 읽는 순서(위 → 아래, 왼 → 오른)로 이어붙인다.
    ///
    /// 세로 위치를 "줄"로 묶은 뒤 그 안에서 가로 위치로 정렬한다. 허용 오차로 두 항목을
    /// 직접 비교하면 `a~b`, `b~c` 인데 `a≁c` 인 경우가 생겨 정렬 기준이 깨지므로 버킷을
    /// 쓴다. 완전히 같은 위치면 transcript 로 갈라 프레임마다 순서가 흔들리지 않게 한다.
    ///
    /// 버킷의 기준점과 크기는 **가이드 박스**에서 가져온다. 뷰 좌표계의 절대 y 를 쓰면
    /// 화면 높이에 따라 버킷 경계가 박스 한가운데에 떨어져, 같은 줄에 있는 두 단어가
    /// 위아래로 갈리고 y 흔들림에 따라 순서가 프레임마다 뒤집힌다. 박스를 기준으로 삼으면
    /// 한 줄짜리 박스의 내용은 전부 같은 버킷에 들어가 가로 순서만 남는다.
    private func joined(_ items: [RecognizedItem]) -> String? {
        let box = regionOfInterest
        let originY = box?.minY ?? 0
        let lineHeight = box.map { max($0.height, 1) } ?? 38

        let texts = items
            .compactMap { item -> (CGPoint, String)? in
                guard case .text(let text) = item else { return nil }
                return (text.bounds.topLeft, text.transcript)
            }
            .sorted { lhs, rhs in
                let lhsLine = ((lhs.0.y - originY) / lineHeight).rounded(.down)
                let rhsLine = ((rhs.0.y - originY) / lineHeight).rounded(.down)
                if lhsLine != rhsLine { return lhsLine < rhsLine }
                if lhs.0.x != rhs.0.x { return lhs.0.x < rhs.0.x }
                return lhs.1 < rhs.1
            }
            .map(\.1)

        return texts.isEmpty ? nil : texts.joined(separator: " ")
    }
}

extension DataScannerRecognizer: DataScannerViewControllerDelegate {
    func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }

    func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }

    func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }
}
