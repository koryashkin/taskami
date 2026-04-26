import SwiftUI

struct ErrorBannerModifier: ViewModifier {
    @Binding var error: Error?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        withAnimation { self.error = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring, value: error != nil)
    }
}

extension View {
    func errorBanner(_ error: Binding<Error?>) -> some View {
        modifier(ErrorBannerModifier(error: error))
    }
}
