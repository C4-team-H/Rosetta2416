import SwiftUI

struct MapOverlayHeader: View {
    let isMapRevealed: Bool
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "map.fill")
                .font(GameFont.custom(size: 21, weight: 800))
                .foregroundStyle(MapDesignTokens.ink)
                .frame(width: 48, height: 48)
                .background(MapDesignTokens.accent, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(MapDesignTokens.ink, lineWidth: 3)
                }
                .rotationEffect(.degrees(-3))

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
                    .font(GameFont.custom(size: 18, weight: 800))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(MapDesignTokens.closeButton, in: .rect(cornerRadius: 15))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(MapDesignTokens.ink, lineWidth: 3)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: 22, height: 3)
                    .padding(.top, 7)
            }
            .shadow(color: MapDesignTokens.ink.opacity(0.82), radius: 0, y: 3)
            .accessibilityLabel("Close map")
            .buttonStyle(MapPressButtonStyle())
        }
        .padding(.horizontal, 6)
    }

    private var statusColor: Color {
        isMapRevealed ? MapDesignTokens.completedMarker : MapDesignTokens.blockedMarker
    }
}
