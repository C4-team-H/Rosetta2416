import SwiftUI

struct MapMarkerView: View {
    let marker: MapMarker

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if marker.type == .activeMission {
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
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 1.2).repeatForever(autoreverses: false),
            value: isPulsing
        )
        .onAppear(perform: updatePulseAnimation)
        .onChange(of: reduceMotion) {
            updatePulseAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(marker.title ?? statusName), \(statusName)")
    }

    private var markerSymbol: String {
        switch marker.type {
        case .activeMission:
            "exclamationmark"
        case .completedMission:
            "checkmark"
        case .lockedArea:
            "lock.fill"
        case .importantObject:
            "sparkles"
        case .door:
            "door.left.hand.open"
        case .objective:
            "scope"
        case .checkpoint:
            "flag.fill"
        }
    }

    private var markerColor: Color {
        switch marker.type {
        case .activeMission:
            .yellow
        case .completedMission:
            .green
        case .lockedArea:
            .gray
        case .importantObject:
            .purple
        case .door:
            .mint
        case .objective:
            .cyan
        case .checkpoint:
            .blue
        }
    }

    private var statusName: String {
        switch marker.type {
        case .activeMission:
            "active mission"
        case .completedMission:
            "completed mission"
        case .lockedArea:
            "locked area"
        case .importantObject:
            "important object"
        case .door:
            "door"
        case .objective:
            "objective"
        case .checkpoint:
            "checkpoint"
        }
    }

    private func updatePulseAnimation() {
        isPulsing = marker.type == .activeMission && !reduceMotion
    }
}
