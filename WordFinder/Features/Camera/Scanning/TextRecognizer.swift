import Foundation

enum RecognizerError: Error, Equatable {
    case unsupportedDevice
    case permissionDenied
}

/// 박스 안에 보이는 텍스트를 계속 흘려보내는 인식기.
///
/// 프로토콜로 둔 이유는 두 가지다. 첫째, PLAN.md §8이 비교하라고 한 두 방식
/// (VisionKit `DataScannerViewController` ↔ `AVCaptureSession` + Vision) 을
/// 화면·상태 로직을 건드리지 않고 갈아끼우기 위해서. 둘째, 테스트에서 카메라 없이
/// 가짜를 주입하기 위해서다.
/// `DataScannerViewController` 가 `@MainActor` 격리 타입이므로 프로토콜도 함께
/// 격리한다. 상태 머신과 화면도 모두 메인 액터에서 돈다.
@MainActor
protocol TextRecognizer: AnyObject {
    /// 프레임마다 호출된다. 박스 안에 아무것도 없으면 `nil`.
    var onText: ((String?) -> Void)? { get set }

    func startScanning() throws
    func stopScanning()

    static var isSupported: Bool { get }
}
