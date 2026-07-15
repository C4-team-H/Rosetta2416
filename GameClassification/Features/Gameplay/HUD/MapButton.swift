import SwiftUI

struct MapButton: View {
    let action: () -> Void

    var body: some View {
        Button("Open map", systemImage: "map.fill", action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 9, y: 4)
            .buttonStyle(MapPressButtonStyle())
            .accessibilityHint("Shows the full station map")
    }
}
