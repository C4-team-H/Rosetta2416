import SwiftUI

struct MapOverlayHeader: View {
    let isMapRevealed: Bool
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(.mapIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .padding(13)
                .background(MapDesignTokens.accent, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(MapDesignTokens.ink, lineWidth: 3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("TACTICAL MAP")
                    .font(GameFont.custom(size: 24, weight: 800))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)

                    Text(isMapRevealed ? "SHIP SCAN ONLINE" : "SHIP SCAN OFFLINE")
                        .font(GameFont.custom(size: 10, weight: 700))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 17)
                            .fill(MapDesignTokens.ink.opacity(0.9))
                            .offset(y: 4)

                        RoundedRectangle(cornerRadius: 17)
                            .fill(MapDesignTokens.closeButton)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 17)
                            .strokeBorder(MapDesignTokens.ink, lineWidth: 4)
                    }
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.34))
                            .frame(width: 26, height: 3)
                            .padding(.top, 7)
                    }
            }
            .accessibilityLabel("Close map")
            .accessibilityHint("Returns to gameplay")
            .buttonStyle(MapCloseButtonStyle())
        }
        .padding(.horizontal, 6)
    }

    private var statusColor: Color {
        isMapRevealed ? MapDesignTokens.completedMarker : MapDesignTokens.blockedMarker
    }
}

private struct MapCloseButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 3 : 0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
