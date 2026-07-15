import SwiftUI

struct MapPlayerMarkerView: View {
    let player: MapPlayerPosition
    var connectionState: TeammateConnectionState?

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if player.isLocalPlayer {
                Circle()
                    .stroke(.cyan.opacity(0.72), lineWidth: 2)
                    .frame(width: 34, height: 34)
                    .scaleEffect(isPulsing ? 1.42 : 0.82)
                    .opacity(isPulsing ? 0 : 1)
            }

            Image(systemName: markerSymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(player.isLocalPlayer ? .black : .white)
                .frame(width: 27, height: 27)
                .background(markerColor, in: Circle())
                .overlay {
                    Circle().stroke(.white, lineWidth: player.isLocalPlayer ? 2.5 : 1.5)
                }

            if let connectionState, connectionState != .connected {
                Image(systemName: connectionSymbol(for: connectionState))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(connectionColor(for: connectionState), in: Circle())
                    .offset(x: 14, y: -14)
            }

            Text(player.isLocalPlayer ? "YOU" : "CREW")
                .font(.caption)
                .bold()
                .lineLimit(1)
                .fixedSize()
                .offset(y: 26)
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

    private var markerSymbol: String {
        if player.isLocalPlayer {
            "location.fill"
        } else if differentiateWithoutColor {
            "person.2.fill"
        } else {
            "person.fill"
        }
    }

    private var markerColor: Color {
        player.isLocalPlayer ? .cyan : .orange
    }

    private var accessibilityLabel: String {
        if player.isLocalPlayer {
            "Your position"
        } else if let connectionState {
            "\(player.name) position, \(connectionState.accessibilityDescription)"
        } else {
            "\(player.name) position"
        }
    }

    private func connectionSymbol(for state: TeammateConnectionState) -> String {
        state == .reconnecting ? "arrow.trianglehead.2.clockwise.rotate.90" : "wifi.slash"
    }

    private func connectionColor(for state: TeammateConnectionState) -> Color {
        state == .reconnecting ? .orange : .red
    }

    private func updatePulseAnimation() {
        isPulsing = player.isLocalPlayer && !reduceMotion
    }
}
