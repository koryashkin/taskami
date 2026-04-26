import Foundation

struct QueryEngine {

    /// Parse a search string and return a predicate closure that matches TaskItems.
    static func compile(_ query: String) -> (TaskItem) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return { _ in true } }

        let tokens = QueryTokenizer.tokenize(trimmed)
        guard let ast = QueryASTParser.parse(tokens) else { return { _ in true } }

        return { item in evaluate(ast, against: item) }
    }

    // MARK: - Evaluation

    private static func evaluate(_ expr: QueryExpression, against item: TaskItem) -> Bool {
        switch expr {
        case .and(let lhs, let rhs):
            return evaluate(lhs, against: item) && evaluate(rhs, against: item)

        case .or(let lhs, let rhs):
            return evaluate(lhs, against: item) || evaluate(rhs, against: item)

        case .not(let inner):
            return !evaluate(inner, against: item)

        case .tagExists(let name):
            return item.tags.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }

        case .hasAnyTag:
            return !item.tags.isEmpty

        case .predicate(let attribute, let relation, let value):
            return evaluatePredicate(attribute: attribute, relation: relation, value: value, item: item)
        }
    }

    private static func evaluatePredicate(attribute: String?, relation: String, value: String, item: TaskItem) -> Bool {
        let attr = attribute ?? "line"

        // Tag attributes: @tagname
        if attr.hasPrefix("@") {
            let tagName = String(attr.dropFirst())
            return evaluateTagPredicate(tagName: tagName, relation: relation, value: value, item: item)
        }

        // Standard attributes
        let itemValue = attributeValue(attr, for: item)

        switch attr {
        case "level", "index":
            // Numeric comparison
            if let numValue = Double(value), let itemNum = Double(itemValue) {
                return compareNumeric(itemNum, relation: relation, to: numValue)
            }
            return compareString(itemValue, relation: relation, to: value)

        case "project":
            // Special: match self if project, or any ancestor project
            return evaluateProjectPredicate(relation: relation, value: value, item: item)

        default:
            return compareString(itemValue, relation: relation, to: value)
        }
    }

    /// Get the string value of an attribute for a TaskItem.
    private static func attributeValue(_ attribute: String, for item: TaskItem) -> String {
        switch attribute {
        case "line":
            return TaskPaperSerializer.serializeLine(item, lineEnding: "").trimmingCharacters(in: .newlines)
        case "content":
            return item.content
        case "type":
            return item.type.rawValue
        case "level":
            return String(item.indentLevel)
        case "index":
            if let parent = item.parent {
                return String(parent.children.firstIndex(where: { $0.id == item.id }) ?? 0)
            }
            return "0"
        case "project":
            return item.content
        default:
            return item.content
        }
    }

    /// Evaluate a @tag predicate.
    /// Ported from QueryParser.m workOnCompletePredicateAssembly: tag handling
    private static func evaluateTagPredicate(tagName: String, relation: String, value: String, item: TaskItem) -> Bool {
        let matchingTags = item.tags.filter {
            $0.name.caseInsensitiveCompare(tagName) == .orderedSame
        }

        guard !matchingTags.isEmpty else { return false }

        // If value is empty, just checking tag existence
        if value.isEmpty { return true }

        // Check if any matching tag's value satisfies the relation
        return matchingTags.contains { tag in
            let tagValue = tag.value ?? ""

            // Try numeric comparison first
            if let numValue = Double(value), let tagNum = tag.numberValue {
                return compareNumeric(tagNum, relation: relation, to: numValue)
            }

            return compareString(tagValue, relation: relation, to: value)
        }
    }

    /// Special project attribute: matches the item's content if it's a project,
    /// or any ancestor project's content.
    /// Ported from QueryParser.m lines 451-457
    private static func evaluateProjectPredicate(relation: String, value: String, item: TaskItem) -> Bool {
        // Check self if it's a project
        if item.type == .project && compareString(item.content, relation: relation, to: value) {
            return true
        }

        // Check ancestor projects
        for ancestor in item.ancestors {
            if ancestor.type == .project && compareString(ancestor.content, relation: relation, to: value) {
                return true
            }
        }

        return false
    }

    // MARK: - Comparison

    private static func compareString(_ lhs: String, relation: String, to rhs: String) -> Bool {
        switch relation {
        case "=":
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedSame
        case "!=":
            return lhs.localizedCaseInsensitiveCompare(rhs) != .orderedSame
        case ">":
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
        case ">=":
            return lhs.localizedCaseInsensitiveCompare(rhs) != .orderedAscending
        case "<":
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        case "<=":
            return lhs.localizedCaseInsensitiveCompare(rhs) != .orderedDescending
        case "beginswith":
            return lhs.localizedCaseInsensitiveContains(rhs) && lhs.lowercased().hasPrefix(rhs.lowercased())
        case "contains":
            return lhs.localizedCaseInsensitiveContains(rhs)
        case "endswith":
            return lhs.lowercased().hasSuffix(rhs.lowercased())
        case "like":
            // "like" uses * and ? wildcards — convert to regex
            return matchesLikePattern(lhs, pattern: rhs)
        case "matches":
            // "matches" is a regex match
            return matchesRegex(lhs, pattern: rhs)
        default:
            return lhs.localizedCaseInsensitiveContains(rhs)
        }
    }

    private static func compareNumeric(_ lhs: Double, relation: String, to rhs: Double) -> Bool {
        switch relation {
        case "=": return lhs == rhs
        case "!=": return lhs != rhs
        case ">": return lhs > rhs
        case ">=": return lhs >= rhs
        case "<": return lhs < rhs
        case "<=": return lhs <= rhs
        default: return lhs == rhs
        }
    }

    private static func matchesLikePattern(_ string: String, pattern: String) -> Bool {
        // Convert "like" wildcards (* and ?) to regex
        var regex = "^"
        for c in pattern {
            switch c {
            case "*": regex += ".*"
            case "?": regex += "."
            default: regex += NSRegularExpression.escapedPattern(for: String(c))
            }
        }
        regex += "$"
        return matchesRegex(string, pattern: regex)
    }

    private static func matchesRegex(_ string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
}
