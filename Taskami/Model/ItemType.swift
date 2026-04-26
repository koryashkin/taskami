import Foundation

enum ItemType: String, Sendable, Equatable, Codable, CaseIterable {
    case project
    case task
    case note
}
