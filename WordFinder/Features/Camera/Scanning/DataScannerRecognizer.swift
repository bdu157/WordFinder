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
        } catch {
            // .cameraRestricted 및 권한 거부·화면 잠김 등이 여기로 온다.
            throw RecognizerError.permissionDenied
        }
    }

    func stopScanning() {
        controller.stopScanning()
    }

    /// 박스 안 항목들을 화면 왼쪽→오른쪽 순으로 이어붙인다.
    private func joined(_ items: [RecognizedItem]) -> String? {
        let texts = items
            .compactMap { item -> (CGFloat, String)? in
                guard case .text(let text) = item else { return nil }
                return (text.bounds.topLeft.x, text.transcript)
            }
            .sorted { $0.0 < $1.0 }
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
