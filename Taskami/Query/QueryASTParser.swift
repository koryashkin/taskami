import Foundation

/// AST for the TaskPaper query grammar.
/// Ported from QueryParser.m grammar:
///   expression          = term orTerm*
///   term                = notFactor andNotFactor*
///   orTerm              = 'or' term
///   notFactor           = 'not'* primaryExpression
///   andNotFactor        = 'and' notFactor
///   primaryExpression   = predicate | '(' expression ')'
///   predicate           = completePredicate | attributeValuePredicate | attributePredicate | valuePredicate
///   completePredicate   = attribute relation value
///   attributeValuePredicate = attribute value
///   attributePredicate  = attribute
///   valuePredicate      = value
indirect enum QueryExpression: Equatable {
    case and(QueryExpression, QueryExpression)
    case or(QueryExpression, QueryExpression)
    case not(QueryExpression)
    case predicate(attribute: String?, relation: String, value: String)
    /// Special case: just checking if a tag exists (e.g. bare "@done")
    case tagExists(name: String)
    /// Special case: "@" alone means "has any tags"
    case hasAnyTag
}

struct QueryASTParser {

    // Keywords from the original QueryParser.m
    static let logicKeywords: Set<String> = ["or", "and", "not"]
    static let relationKeywords: Set<String> = ["beginswith", "contains", "endswith", "like", "matches"]
    static let attributeKeywords: Set<String> = ["line", "project", "index", "content", "type", "level"]

    private var tokens: [QueryToken]
    private var pos: Int

    static func parse(_ tokens: [QueryToken]) -> QueryExpression? {
        guard !tokens.isEmpty else { return nil }
        var parser = QueryASTParser(tokens: tokens, pos: 0)
        return parser.parseExpression()
    }

    // MARK: - Grammar rules

    // expression = term orTerm*
    private mutating func parseExpression() -> QueryExpression? {
        guard var left = parseTerm() else { return nil }

        while matchKeyword("or") {
            guard let right = parseTerm() else { break }
            left = .or(left, right)
        }

        return left
    }

    // term = notFactor andNotFactor*
    private mutating func parseTerm() -> QueryExpression? {
        guard var left = parseNotFactor() else { return nil }

        while matchKeyword("and") {
            guard let right = parseNotFactor() else { break }
            left = .and(left, right)
        }

        return left
    }

    // notFactor = 'not'* primaryExpression
    private mutating func parseNotFactor() -> QueryExpression? {
        var notCount = 0
        while matchKeyword("not") {
            notCount += 1
        }

        guard var expr = parsePrimaryExpression() else { return nil }

        if notCount % 2 == 1 {
            expr = .not(expr)
        }

        return expr
    }

    // primaryExpression = '(' expression ')' | predicate
    private mutating func parsePrimaryExpression() -> QueryExpression? {
        if matchToken(.leftParen) {
            let expr = parseExpression()
            _ = matchToken(.rightParen) // consume closing paren
            return expr
        }
        return parsePredicate()
    }

    // predicate = completePredicate | attributeValuePredicate | attributePredicate | valuePredicate
    private mutating func parsePredicate() -> QueryExpression? {
        let savedPos = pos

        // Try completePredicate: attribute relation value
        if let attribute = parseAttribute() {
            let savedPos2 = pos
            if let relation = parseRelation(), let value = parseValue() {
                return buildPredicate(attribute: attribute, relation: relation, value: value)
            }
            // Try attributeValuePredicate: attribute value
            pos = savedPos2
            if let value = parseValue() {
                return buildPredicate(attribute: attribute, relation: "contains", value: value)
            }
            // attributePredicate: just attribute
            pos = savedPos2
            return buildAttributeOnlyPredicate(attribute: attribute)
        }

        // valuePredicate: value (searches selfString/line by default)
        pos = savedPos
        if let value = parseValue() {
            return .predicate(attribute: "line", relation: "contains", value: value)
        }

        return nil
    }

    // attribute = @word | attributeKeywords
    private mutating func parseAttribute() -> String? {
        guard pos < tokens.count else { return nil }

        if case .word(let w) = tokens[pos] {
            let lower = w.lowercased()

            // @-prefixed tag attributes
            if w.hasPrefix("@") {
                pos += 1
                return lower
            }

            // Named attributes
            if Self.attributeKeywords.contains(lower) {
                pos += 1
                return lower
            }
        }

        return nil
    }

    // relation = '=' | '!=' | '>' | '>=' | '<' | '<=' | relationKeywords
    private mutating func parseRelation() -> String? {
        guard pos < tokens.count else { return nil }

        switch tokens[pos] {
        case .symbol(let s) where ["=", "!=", ">", ">=", "<", "<="].contains(s):
            pos += 1
            return s
        case .word(let w) where Self.relationKeywords.contains(w.lowercased()):
            pos += 1
            return w.lowercased()
        default:
            return nil
        }
    }

    // value = quotedString | unquotedString (one or more non-reserved words)
    private mutating func parseValue() -> String? {
        guard pos < tokens.count else { return nil }

        if case .quotedString(let s) = tokens[pos] {
            pos += 1
            return s
        }

        // Unquoted string: one or more non-reserved words
        var words: [String] = []
        while pos < tokens.count {
            if case .word(let w) = tokens[pos] {
                let lower = w.lowercased()
                // Stop at reserved words
                if Self.logicKeywords.contains(lower) ||
                   Self.relationKeywords.contains(lower) ||
                   Self.attributeKeywords.contains(lower) ||
                   w.hasPrefix("@") {
                    break
                }
                words.append(w)
                pos += 1
            } else {
                break
            }
        }

        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    // MARK: - Helpers

    private mutating func matchKeyword(_ keyword: String) -> Bool {
        guard pos < tokens.count else { return false }
        if case .word(let w) = tokens[pos], w.caseInsensitiveCompare(keyword) == .orderedSame {
            pos += 1
            return true
        }
        return false
    }

    private mutating func matchToken(_ token: QueryToken) -> Bool {
        guard pos < tokens.count, tokens[pos] == token else { return false }
        pos += 1
        return true
    }

    /// Build a predicate expression, handling special attribute mappings.
    /// Ported from QueryParser.m workOnCompletePredicateAssembly:
    private func buildPredicate(attribute: String, relation: String, value: String) -> QueryExpression {
        // Map attribute names to match original behavior
        var attr = attribute
        if attr == "line" { attr = "line" }  // selfString in original
        if attr == "type" { attr = "type" }  // typeAsString in original

        if attr.hasPrefix("@") {
            // Tag attribute query
            return .predicate(attribute: attr, relation: relation, value: value)
        }

        return .predicate(attribute: attr, relation: relation, value: value)
    }

    /// Build a predicate for a bare attribute (no relation or value).
    /// For @tags: check if tag exists. For others: check if non-empty.
    private func buildAttributeOnlyPredicate(attribute: String) -> QueryExpression {
        if attribute == "@" {
            return .hasAnyTag
        }
        if attribute.hasPrefix("@") {
            let tagName = String(attribute.dropFirst())
            if tagName.isEmpty {
                return .hasAnyTag
            }
            return .tagExists(name: tagName)
        }
        // For non-tag attributes, default: attribute contains ""
        return .predicate(attribute: attribute, relation: "contains", value: "")
    }
}
