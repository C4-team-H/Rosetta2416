import SwiftUI

struct MapOverlayHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STATION MAP")
                    .font(GameFont.title2Bold)
                Text("Live crew and mission positions")
                    .font(GameFont.caption1)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("Close map", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(GameFont.headline)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.1), in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .buttonStyle(MapPressButtonStyle())
        }
    }
}
