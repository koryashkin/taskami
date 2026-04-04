import Foundation

enum AppError: LocalizedError {
    case fileNotFound(URL)
    case fileReadFailed(URL, underlying: Error)
    case fileWriteFailed(URL, underlying: Error)
    case parseError(line: Int, description: String)
    case encodingError(URL)
    case iCloudUnavailable
    case biometricUnavailable

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileReadFailed(let url, _):
            return "Unable to read \(url.lastPathComponent)"
        case .fileWriteFailed(let url, _):
            return "Unable to save \(url.lastPathComponent)"
        case .parseError(let line, let desc):
            return "Parse error at line \(line): \(desc)"
        case .encodingError(let url):
            return "Unable to decode \(url.lastPathComponent)"
        case .iCloudUnavailable:
            return "iCloud is not available"
        case .biometricUnavailable:
            return "Biometric authentication is not available on this device"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "The file may have been moved or deleted."
        case .fileReadFailed:
            return "Check that you have permission to read this file."
        case .fileWriteFailed:
            return "Check that you have permission to write to this location."
        case .parseError:
            return "The file may be corrupted. Try opening it in a text editor."
        case .encodingError:
            return "The file encoding is not supported. Try saving it as UTF-8."
        case .iCloudUnavailable:
            return "Sign in to iCloud in Settings, or files will be stored locally."
        case .biometricUnavailable:
            return "Set up Face ID or Touch ID in Settings."
        }
    }
}
