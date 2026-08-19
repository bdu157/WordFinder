import Testing
@testable import WordFinder

@Test func splitsOnWhitespace() {
    let words = WordTokenizer.tokenize("resilient urban systems")
    #expect(words.map(\.term) == ["resilient", "urban", "systems"])
}

@Test func stripsSurroundingPunctuation() {
    let words = WordTokenizer.tokenize("\"resilient,\" (urban) systems.")
    #expect(words.map(\.term) == ["resilient", "urban", "systems"])
}

@Test func keepsInnerHyphenAndApostrophe() {
    let words = WordTokenizer.tokenize("well-being doesn't")
    #expect(words.map(\.term) == ["well-being", "doesn't"])
}

@Test func collapsesRepeatedWhitespaceAndNewlines() {
    let words = WordTokenizer.tokenize("  resilient \n\n  urban  ")
    #expect(words.map(\.term) == ["resilient", "urban"])
}

@Test func dropsTokensShorterThanTwoCharacters() {
    let words = WordTokenizer.tokenize("a resilient I system")
    #expect(words.map(\.term) == ["resilient", "system"])
}

@Test func returnsEmptyForBlankInput() {
    #expect(WordTokenizer.tokenize("   ").isEmpty)
    #expect(WordTokenizer.tokenize("").isEmpty)
}

@Test func dropsPurePunctuationTokens() {
    let words = WordTokenizer.tokenize("resilient --- urban")
    #expect(words.map(\.term) == ["resilient", "urban"])
}

/// Pins that a typographic apostrophe inside a word survives tokenization —
/// Vision emits U+2019 for printed text. This does NOT distinguish whether
/// U+2019 sits in `allowedInside`: `trimOuterPunctuation` only inspects the
/// first and last character, so an interior apostrophe is untouched either way.
@Test func keepsCurlyApostropheInsideWord() {
    let curly = "\u{2019}"
    let words = WordTokenizer.tokenize("doesn\(curly)t well-being")
    #expect(words.map(\.term) == ["doesn\(curly)t", "well-being"])
}
