import SwiftUI
import UIKit

/// iOS 내장 영영사전(`UIReferenceLibraryViewController`)을 SwiftUI 에 얹는다.
///
/// 온라인 사전에 없거나 응답하지 않을 때의 폴백이다. 오프라인에서도 동작해서 비행기 모드에서도
/// 뜻이 나온다. 영어 사전을 기기에 내려받지 않았으면 iOS 가 "정의 없음"과 사전 관리 버튼을
/// 보여준다 — iOS 동작이라 여기서 바꿀 수 없다.
struct SystemDictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
