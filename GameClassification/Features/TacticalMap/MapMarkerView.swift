import SwiftUI

struct MapMarkerView: View {
    let marker: MapMarker

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if marker.status == .active {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(markerColor.opacity(0.7), lineWidth: 2)
                    .frame(width: 27, height: 27)
                    .scaleEffect(isPulsing ? 1.45 : 0.85)
                    .opacity(isPulsing ? 0 : 1)
            }

            Image(systemName: markerSymbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 21, height: 21)
                .background(markerColor, in: .rect(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.72), lineWidth: 1) }
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
            case .objective, .station: return "scope"
            }
        }
    }

    private var markerColor: Color {
        switch marker.status {
        case .active: .yellow
        case .completed: .green
        case .locked: .gray
        case .unlocked: .cyan
        case .blocked: .red
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
