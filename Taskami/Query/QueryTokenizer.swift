import Foundation

enum QueryToken: Equatable {
    case word(String)
    case quotedString(String)
    case symbol(String)        // =, !=, >, >=, <, <=
    case leftParen
    case rightParen

    var stringValue: String {
        switch self {
        case .word(let s): return s
        case .quotedString(let s): return s
        case .symbol(let s): return s
        case .leftParen: return "("
        case .rightParen: return ")"
        }
    }

    var isWord: Bool {
        if case .word = self { return true }
        return false
    }
}

struct QueryTokenizer {

    static func tokenize(_ input: String) -> [QueryToken] {
        var tokens: [QueryToken] = []
        var index = input.startIndex

        while index < input.endIndex {
            let c = input[index]

            // Skip whitespace
            if c.isWhitespace {
                index = input.index(after: index)
                continue
            }

            // Quoted string
            if c == "\"" {
                let str = readQuotedString(input, from: &index)
                tokens.append(.quotedString(str))
                continue
            }

            // Parentheses
            if c == "(" {
                tokens.append(.leftParen)
                index = input.index(after: index)
                continue
            }
            if c == ")" {
                tokens.append(.rightParen)
                index = input.index(after: index)
                continue
            }

            // Two-character symbols: !=, >=, <=
            if index < input.index(before: input.endIndex) {
                let next = input[input.index(after: index)]
                let twoChar = String(c) + String(next)
                if twoChar == "!=" || twoChar == ">=" || twoChar == "<=" {
                    tokens.append(.symbol(twoChar))
                    index = input.index(index, offsetBy: 2)
                    continue
                }
            }

            // Single-character symbols: =, >, <
            if c == "=" || c == ">" || c == "<" {
                tokens.append(.symbol(String(c)))
                index = input.index(after: index)
                continue
            }

            // Word (including @-prefixed words, numbers, dashes, dots)
            let word = readWord(input, from: &index)
            if !word.isEmpty {
                tokens.append(.word(word))
            }
        }

        return tokens
    }

    private static func readQuotedString(_ input: String, from index: inout String.Index) -> String {
        // Skip opening quote
        index = input.index(after: index)
        var result = ""
        while index < input.endIndex {
            let c = input[index]
            if c == "\"" {
                index = input.index(after: index)
                return result
            }
            result.append(c)
            index = input.index(after: index)
        }
        // Unterminated quote — return what we have
        return result
    }

    private static func readWord(_ input: String, from index: inout String.Index) -> String {
        var result = ""
        while index < input.endIndex {
            let c = input[index]
            if c.isWhitespace || c == "(" || c == ")" || c == "\"" || c == "=" || c == ">" || c == "<" {
                break
            }
            // Allow ! only as part of != (not standalone)
            if c == "!" {
                let next = input.index(after: index)
                if next < input.endIndex && input[next] == "=" {
                    break
                }
            }
            result.append(c)
            index = input.index(after: index)
        }
        return result
    }
}
