import SwiftUI

struct MapPlayerMarkerView: View {
    let player: MapPlayerPosition

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if player.isLocalPlayer {
                Circle()
                    .stroke(MapDesignTokens.ink, lineWidth: 5)
                    .overlay {
                        Circle().stroke(MapDesignTokens.localCrew, lineWidth: 2)
                    }
                    .frame(width: 38, height: 38)
                    .scaleEffect(isPulsing ? 1.45 : 0.8)
                    .opacity(isPulsing ? 0 : 1)
            }

            markerGlyph

            if differentiateWithoutColor && player.isLocalPlayer {
                Image(systemName: "star.fill")
                    .font(GameFont.custom(size: 7, weight: 800))
                    .foregroundStyle(MapDesignTokens.activeMarker)
                    .padding(3)
                    .background(MapDesignTokens.ink, in: .circle)
                    .offset(x: -14, y: -13)
            }

            Text(player.isLocalPlayer ? "YOU" : "CREW")
                .font(GameFont.custom(size: 8, weight: 800))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(height: 15)
                .background(MapDesignTokens.ink.opacity(0.9), in: .capsule)
                .overlay { Capsule().stroke(.white.opacity(0.24), lineWidth: 1) }
                .lineLimit(1)
                .fixedSize()
                .offset(y: 27)
        }
        .opacity(player.isConnected ? 1 : 0.52)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 1.15).repeatForever(autoreverses: false),
            value: isPulsing
        )
        .onAppear(perform: updatePulseAnimation)
        .onChange(of: reduceMotion) {
            updatePulseAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var markerColor: Color {
        player.isLocalPlayer ? MapDesignTokens.localCrew : MapDesignTokens.teammateCrew
    }

    @ViewBuilder
    private var markerGlyph: some View {
        if player.isLocalPlayer {
            Image("YouIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24)
        } else {
            MapCrewmateGlyph(suitColor: markerColor)
                .frame(width: 20, height: 20)
        }
    }

    private var accessibilityLabel: String {
        if player.isLocalPlayer {
            "Your position"
        } else {
            "\(player.name) position"
        }
    }

    private func updatePulseAnimation() {
        isPulsing = player.isLocalPlayer && !reduceMotion
    }
}

private struct MapCrewmateGlyph: View {
    let suitColor: Color

    var body: some View {
        ZStack {
            HStack(spacing: 3) {
                crewPart(width: 6, height: 10, cornerRadius: 2.5)
                crewPart(width: 6, height: 10, cornerRadius: 2.5)
            }
            .offset(x: 2, y: 9)

            crewPart(width: 7, height: 14, cornerRadius: 3)
                .offset(x: -9, y: 1)

            crewPart(width: 19, height: 22, cornerRadius: 8)
                .offset(x: 1, y: -1)

            Capsule()
                .fill(MapDesignTokens.visor)
                .frame(width: 13, height: 8)
                .overlay {
                    Capsule().stroke(MapDesignTokens.ink, lineWidth: 2)
                }
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(.white.opacity(0.55))
                        .frame(width: 5, height: 2)
                        .padding(.leading, 3)
                        .padding(.top, 2)
                }
                .offset(x: 4, y: -5)
        }
    }

    private func crewPart(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(suitColor)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MapDesignTokens.ink, lineWidth: 2)
            }
    }
}
