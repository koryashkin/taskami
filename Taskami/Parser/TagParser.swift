import Foundation

struct TagParser {

    // Matches: (optional leading whitespace)@name or @name(value)
    // Ported from Tag.m: TagRegex = @"(?:^|\\s)@([^\\(\\s]*)(?:\\(([^\\)]+)\\))?"
    private static let tagPattern: NSRegularExpression = {
        guard let re = try? NSRegularExpression(pattern: #"(?:^|\s)@([^\(\s]*)(?:\(([^\)]+)\))?"#) else {
            fatalError("tagPattern regex is invalid")
        }
        return re
    }()

    // Matches trailing tags at end of string
    // Ported from Tag.m: TrailingTagsRegex = @"(?:(?:^|\\s)@([^\\(\\s]*)(\\([^\\)]*\\))?)+$"
    private static let trailingTagsPattern: NSRegularExpression = {
        guard let re = try? NSRegularExpression(pattern: #"(?:(?:^|\s)@([^\(\s]*)(\([^\)]*\))?)+$"#) else {
            fatalError("trailingTagsPattern regex is invalid")
        }
        return re
    }()

    /// Parse all @tags from a content string.
    static func parseTags(in string: String) -> [Tag] {
        guard string.contains("@") else { return [] }

        let nsString = string as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = tagPattern.matches(in: string, range: range)

        return matches.compactMap { match -> Tag? in
            guard match.numberOfRanges >= 2 else { return nil }
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound else { return nil }

            let name = nsString.substring(with: nameRange)
            var value: String?
            if match.numberOfRanges >= 3 {
                let valueRange = match.range(at: 2)
                if valueRange.location != NSNotFound {
                    value = nsString.substring(with: valueRange)
                }
            }
            return Tag(name: name, value: value)
        }
    }

    /// Parse tags with their ranges in the original string.
    static func parseTagsWithRanges(in string: String) -> [(tag: Tag, range: Range<String.Index>)] {
        guard string.contains("@") else { return [] }

        let nsString = string as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = tagPattern.matches(in: string, range: range)

        return matches.compactMap { match -> (Tag, Range<String.Index>)? in
            guard match.numberOfRanges >= 2,
                  let fullRange = Range(match.range, in: string) else { return nil }

            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound else { return nil }

            let name = nsString.substring(with: nameRange)
            var value: String?
            if match.numberOfRanges >= 3 {
                let valueRange = match.range(at: 2)
                if valueRange.location != NSNotFound {
                    value = nsString.substring(with: valueRange)
                }
            }

            // Trim leading whitespace from the full match range for the tag range
            var tagStart = fullRange.lowerBound
            if tagStart != string.startIndex && (string[tagStart] == " " || string[tagStart] == "\t") {
                tagStart = string.index(after: tagStart)
            }

            return (Tag(name: name, value: value), tagStart..<fullRange.upperBound)
        }
    }

    /// Find the range of trailing tags (tags at end of line).
    static func trailingTagsRange(in string: String) -> Range<String.Index>? {
        trailingTagsRange(in: string, searchRange: string.startIndex..<string.endIndex)
    }

    /// Find the range of trailing tags within a specified range.
    static func trailingTagsRange(in string: String, searchRange: Range<String.Index>) -> Range<String.Index>? {
        guard string.contains("@") else { return nil }

        let nsRange = NSRange(searchRange, in: string)
        guard let match = trailingTagsPattern.firstMatch(in: string, range: nsRange) else {
            return nil
        }
        return Range(match.range, in: string)
    }
}
