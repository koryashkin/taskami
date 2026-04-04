import Foundation
import LocalAuthentication
import Observation

@Observable
final class AuthenticationService {
    var isAuthenticated: Bool = false
    var lastBackgroundDate: Date?

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometric"
        }
    }

    @MainActor
    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Taskami"
            )
            isAuthenticated = success
            return success
        } catch {
            isAuthenticated = false
            return false
        }
    }

    func shouldLock(timeout: TimeInterval = 0) -> Bool {
        guard let lastBackground = lastBackgroundDate else { return false }
        return Date().timeIntervalSince(lastBackground) > timeout
    }
}
