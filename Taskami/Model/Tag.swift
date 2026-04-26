import Foundation

struct Tag: Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    var name: String
    var value: String?

    init(name: String, value: String? = nil) {
        self.id = UUID()
        self.name = name
        self.value = (value?.isEmpty ?? true) ? nil : value
    }

    var description: String {
        if let value, !value.isEmpty {
            return "@\(name)(\(value))"
        }
        return "@\(name)"
    }

    var numberValue: Double? {
        guard let value else { return nil }
        return Double(value)
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
    }
}
