import SwiftUI
import VisionKit

/// `DataScannerViewController` 를 SwiftUI 계층에 얹는다. 화면에는 카메라
/// 프리뷰만 보이고, 가이드 박스·블러·브래킷은 `CameraView` 가 이 위에 그린다.
struct ScannerViewRepresentable: UIViewControllerRepresentable {
    let recognizer: DataScannerRecognizer
    let regionOfInterest: CGRect

    func makeUIViewController(context: Context) -> DataScannerViewController {
        recognizer.regionOfInterest = regionOfInterest
        recognizer.controller.regionOfInterest = regionOfInterest
        return recognizer.controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        // 회전·레이아웃 변화로 박스 위치가 바뀌면 따라간다.
        recognizer.regionOfInterest = regionOfInterest
        controller.regionOfInterest = regionOfInterest
    }
}
