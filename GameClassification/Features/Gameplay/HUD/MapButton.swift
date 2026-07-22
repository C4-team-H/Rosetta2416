import SwiftUI

struct MapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.mapIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding(13)
                .frame(
                    width: GameplayHUDLayout.buttonDiameter,
                    height: GameplayHUDLayout.buttonDiameter
                )
                .contentShape(Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 9, y: 4)
        }
        .buttonStyle(MapPressButtonStyle())
//        .background(.ultraThinMaterial, in: Circle())
//        .overlay {
//            Circle().stroke(.white.opacity(0.24), lineWidth: 1)
//        }
//        .shadow(color: .black.opacity(0.35), radius: 9, y: 4)
        .accessibilityLabel("Open map")
        .accessibilityHint("Shows the full station map")
    }
}
