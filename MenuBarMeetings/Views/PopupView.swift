import SwiftUI

struct PopupView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Your schedule will appear here")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Divider()

            HStack {
                Button("Preferences") {
                    // Stub — wired up in Sprint 5
                }
                .disabled(true)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
        }
        .frame(width: 320, height: 400)
    }
}
