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
    /// 인식 결과가 바뀔 때마다 호출된다. 박스 안에 읽을 것이 없으면 `nil`.
    ///
    /// **프레임 단위가 아니라 이벤트 단위다.** `DataScannerViewController` 의 델리게이트가
    /// 그렇듯, 박스가 계속 비어 있으면 호출이 아예 오지 않을 수 있다. 그래서
    /// `ScanViewModel` 은 별도로 `tick()` 을 굴려 타임아웃을 흐르게 한다.
    ///
    /// 구현자가 지켜야 할 것: 읽히던 텍스트가 박스에서 벗어나면 **반드시 `nil` 을 한 번
    /// 보내야 한다.** 보내지 않으면 `tick()` 이 사라진 텍스트를 계속 다시 먹여, 이미 화면
    /// 밖으로 나간 단어가 확정되어 버린다.
    var onText: ((String?) -> Void)? { get set }

    func startScanning() throws
    func stopScanning()

    static var isSupported: Bool { get }
}
