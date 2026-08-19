import SwiftUI

/// Type scale from the design system: New York (serif) for dictionary content
/// (headwords, definitions, examples), SF Pro (default) for UI chrome.
/// `design: .serif` resolves to New York automatically and keeps Dynamic Type.
extension Font {
    static let wfHeadword = Font.system(size: 40, weight: .semibold, design: .serif)
    static let wfHeadwordSheet = Font.system(size: 36, weight: .semibold, design: .serif)
    static let wfDefinition = Font.system(size: 19, weight: .regular, design: .serif)
    static let wfExample = Font.system(size: 17, weight: .regular, design: .serif).italic()
    static let wfPOSLabel = Font.system(size: 13, weight: .semibold)
    static let wfIPA = Font.system(size: 17, weight: .regular)
    static let wfCaption = Font.system(size: 13, weight: .regular)
    static let wfWordRow = Font.system(size: 19, weight: .regular, design: .serif)
}
