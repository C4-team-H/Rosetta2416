import SwiftUI

struct MapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: "map.fill")
                    .font(GameFont.custom(size: 20, weight: 800))
                Text("MAP")
                    .font(GameFont.custom(size: 8, weight: 800))
            }
            .foregroundStyle(MapDesignTokens.ink)
            .frame(width: 56, height: 56)
            .background(MapDesignTokens.accent, in: .rect(cornerRadius: 17))
        }
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(MapDesignTokens.ink, lineWidth: 4)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: 25, height: 3)
                    .padding(.top, 7)
            }
            .shadow(color: MapDesignTokens.ink.opacity(0.86), radius: 0, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    .padding(5)
            }
            .shadow(color: .black.opacity(0.28), radius: 8, y: 7)
            .buttonStyle(MapPressButtonStyle())
            .accessibilityLabel("Open map")
            .accessibilityHint("Shows the full station map")
    }
}
