import SwiftUI

struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pause.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(
                    width: GameplayHUDLayout.buttonDiameter,
                    height: GameplayHUDLayout.buttonDiameter
                )
                .contentShape(Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 9, y: 4)
        }
        .buttonStyle(MapPressButtonStyle())
        .accessibilityLabel("Pause game")
        .accessibilityHint("Pauses gameplay and opens menu")
    }
}
