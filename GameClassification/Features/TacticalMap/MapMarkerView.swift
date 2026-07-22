import SwiftUI

struct MapMarkerView: View {
    let marker: MapMarker

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if marker.status == .active {
                Circle()
                    .stroke(MapDesignTokens.ink, lineWidth: 4)
                    .overlay { Circle().stroke(markerColor, lineWidth: 2) }
                    .frame(width: 30, height: 30)
                    .scaleEffect(isPulsing ? 1.5 : 0.82)
                    .opacity(isPulsing ? 0 : 1)
            }

            Image(systemName: markerSymbol)
                .font(GameFont.custom(size: 10, weight: 800))
                .foregroundStyle(MapDesignTokens.ink)
                .frame(width: 23, height: 23)
                .background(markerColor, in: .circle)
                .overlay { Circle().stroke(MapDesignTokens.ink, lineWidth: 3) }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.48))
                        .frame(width: 4, height: 4)
                        .padding(5)
                }
                .shadow(color: MapDesignTokens.ink.opacity(0.8), radius: 0, y: 2)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
        .onAppear(perform: updatePulseAnimation)
        .onChange(of: reduceMotion) { updatePulseAnimation() }
        .onChange(of: marker.status) { updatePulseAnimation() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(marker.title ?? statusName), \(statusName)")
    }

    private var markerSymbol: String {
        switch marker.status {
        case .completed: return "checkmark"
        case .locked: return "lock.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .active: return "exclamationmark"
        case .unlocked:
            switch marker.kind {
            case .kitchen: return "fork.knife"
            case .storage: return "shippingbox.fill"
            case .cockpit: return "airplane"
            case .door: return "door.left.hand.open"
            case .room: return "rectangle.split.3x1.fill"
            case .checkpoint: return "flag.fill"
            case .albumBook: return "book.fill"
            case .objective, .station: return "scope"
            }
        }
    }

    private var markerColor: Color {
        switch marker.status {
        case .active: MapDesignTokens.activeMarker
        case .completed: MapDesignTokens.completedMarker
        case .locked: MapDesignTokens.lockedMarker
        case .unlocked: MapDesignTokens.unlockedMarker
        case .blocked: MapDesignTokens.blockedMarker
        }
    }

    private var statusName: String {
        switch marker.status {
        case .active: "active objective"
        case .completed: "completed"
        case .locked: "locked"
        case .unlocked: "unlocked"
        case .blocked: "blocked"
        }
    }

    private func updatePulseAnimation() {
        isPulsing = marker.status == .active && !reduceMotion
    }
}
