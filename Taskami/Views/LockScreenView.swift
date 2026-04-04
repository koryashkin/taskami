import SwiftUI

struct LockScreenView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Taskami is Locked")
                .font(.title2)
                .fontWeight(.medium)

            Button {
                Task {
                    await appState.unlock()
                }
            } label: {
                Label("Unlock with \(appState.authService.biometricName)", systemImage: biometricIcon)
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .task {
            // Auto-prompt on appear
            await appState.unlock()
        }
    }

    private var biometricIcon: String {
        switch appState.authService.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.open"
        }
    }
}
