import Foundation

/// Read-only Markdown layout validation for clarification output.
/// Placeholder punctuation and names are ordinary editable text.
public enum PromptStructureIntegrity {
    private static let headingPattern = #"(?m)^[ \t]{0,3}(#{1,6})[ \t]+(\S.*)$"#
    private static let unorderedListPattern = #"(?m)^[ \t]{0,3}[-*+][ \t]+\S"#
    private static let orderedListPattern = #"(?m)^[ \t]{0,3}\d{1,9}[.)][ \t]+\S"#

    public enum BlockToken: Equatable, Hashable, Sendable {
        case heading(level: Int, title: String)
        case unorderedListItem
        case orderedListItem
    }

    public struct BlockStructure: Equatable, Sendable {
        public let tokens: [BlockToken]

        public init(tokens: [BlockToken]) {
            self.tokens = tokens
        }
    }

    public static func blockStructure(in text: String) -> BlockStructure {
        var tokens: [BlockToken] = []

        for line in text.components(separatedBy: .newlines) {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            if let heading = matches(pattern: headingPattern, in: line, range: range).first,
               heading.numberOfRanges >= 3 {
                let level = nsLine.substring(with: heading.range(at: 1)).count
                let title = nsLine.substring(with: heading.range(at: 2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                tokens.append(.heading(level: level, title: title))
            } else if hasMatch(pattern: unorderedListPattern, in: line, range: range) {
                tokens.append(.unorderedListItem)
            } else if hasMatch(pattern: orderedListPattern, in: line, range: range) {
                tokens.append(.orderedListItem)
            }


        }
        return BlockStructure(tokens: tokens)
    }

    public static func preservesMarkdownBlockStructure(original: String, generated: String) -> Bool {
        isSubsequence(blockStructure(in: original).tokens, of: blockStructure(in: generated).tokens)
    }

    private static func isSubsequence(_ source: [BlockToken], of result: [BlockToken]) -> Bool {
        var searchStart = 0
        for token in source {
            guard searchStart < result.count,
                  let match = result[searchStart...].firstIndex(of: token)
            else { return false }
            searchStart = match + 1
        }
        return true
    }

    private static func matches(pattern: String, in text: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: range)
    }

    private static func hasMatch(pattern: String, in text: String, range: NSRange) -> Bool {
        !matches(pattern: pattern, in: text, range: range).isEmpty
    }
}
