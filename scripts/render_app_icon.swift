// Renders the WordFinder app icon — Concept C ("종이 위의 표제어") — at 1024×1024,
// in the three appearances iOS 18+ uses: light (any), dark, tinted.
//
// Source design: Claude Design canvas "WordFinder 앱 아이콘", artboard ConceptC.
// Geometry is copied 1:1 from its SVG (viewBox 0 0 1024 1024). The serif "a" uses
// New York, the app's own headword font, instead of the canvas's web font.
//
// Usage:  swift scripts/render_app_icon.swift WordFinder/Resources/Assets.xcassets/AppIcon.appiconset
// Override the optical size with OPSZ=<12…256> to compare cuts.
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

struct Palette {
    let background: CGColor
    let bracket: CGColor
    let glyph: CGColor
    let underline: CGColor
}

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

let variants: [(String, Palette)] = [
    ("AppIcon-Light", Palette(background: rgb(0xF7F6F3), bracket: rgb(0x1D3B63), glyph: rgb(0x142946), underline: rgb(0xB26B2E))),
    ("AppIcon-Dark",  Palette(background: rgb(0x161E2C), bracket: rgb(0x7FA6D9), glyph: rgb(0xECEFF4), underline: rgb(0xE0A567))),
    ("AppIcon-Tinted", Palette(background: rgb(0x161616), bracket: rgb(0xBDBDBD), glyph: rgb(0xBDBDBD), underline: rgb(0xFFFFFF))),
]

let size = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// SVG uses a top-left origin with y pointing down; CoreGraphics uses bottom-left, y up.
func flipY(_ y: CGFloat) -> CGFloat { CGFloat(size) - y }

let baseFont = NSFont.systemFont(ofSize: 520, weight: .medium)
guard let serifDescriptor = baseFont.fontDescriptor.withDesign(.serif),
      let displayFont = NSFont(descriptor: serifDescriptor, size: 520) else {
    fatalError("New York (system serif) is not available")
}
// New York is a variable font with an optical-size axis (opsz 12–256). At 520pt it
// picks the display cut (opsz 256), whose hairlines vanish once the icon is shrunk to
// home-screen size. Pinning a text-size cut keeps the same "a" with sturdier thin strokes.
// 32 was chosen by comparing 256/32/20/12 at 180, 120, 87 and 58 px.
let opsz = Double(ProcessInfo.processInfo.environment["OPSZ"] ?? "32")!
let axisOpsz = 0x6F70737A, axisWght = 0x77676874
let serifFont = CTFontCreateCopyWithAttributes(displayFont as CTFont, 520, nil,
    CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute: [axisOpsz: opsz, axisWght: 500]] as CFDictionary)) as NSFont
print("glyph font:", serifFont.fontName)

for (name, p) in variants {
    // Opaque RGB, no alpha — App Store icons must not contain transparency.
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError() }
    ctx.setShouldAntialias(true)

    // <rect width="1024" height="1024">
    ctx.setFillColor(p.background)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // <path d="M232 422L232 272L382 272 M642 272L792 272L792 422
    //          M792 602L792 752L642 752 M382 752L232 752L232 602"
    //       stroke-width="72" stroke-linecap="round" stroke-linejoin="round">
    let brackets: [[(CGFloat, CGFloat)]] = [
        [(232, 422), (232, 272), (382, 272)],
        [(642, 272), (792, 272), (792, 422)],
        [(792, 602), (792, 752), (642, 752)],
        [(382, 752), (232, 752), (232, 602)],
    ]
    let path = CGMutablePath()
    for stroke in brackets {
        path.move(to: CGPoint(x: stroke[0].0, y: flipY(stroke[0].1)))
        for pt in stroke.dropFirst() { path.addLine(to: CGPoint(x: pt.0, y: flipY(pt.1))) }
    }
    ctx.addPath(path)
    ctx.setStrokeColor(p.bracket)
    ctx.setLineWidth(72)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // <text x="512" y="598" text-anchor="middle" font-size="520">a</text>
    // y is the baseline; text-anchor="middle" centers the advance width on x.
    let attrs: [NSAttributedString.Key: Any] = [.font: serifFont, .foregroundColor: NSColor(cgColor: p.glyph)!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "a", attributes: attrs))
    let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: 512 - advance / 2, y: flipY(598))
    CTLineDraw(line, ctx)

    // <rect x="392" y="642" width="240" height="44" rx="22">
    let underline = CGRect(x: 392, y: flipY(642 + 44), width: 240, height: 44)
    ctx.addPath(CGPath(roundedRect: underline, cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.setFillColor(p.underline)
    ctx.fillPath()

    guard let image = ctx.makeImage() else { fatalError() }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError() }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("write failed: \(url.path)") }
    print("wrote", url.path)
}
