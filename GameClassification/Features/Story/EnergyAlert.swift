import Foundation
import SwiftUI

struct LowEnergyAlertOverlay: View {
    let session: GameSessionState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Block tap-through to underlying views; only the GOT IT button dismisses
                }

            ZStack(alignment: .top) {
                Image("LowEnergyPopUp")
                    .resizable()
                    .scaledToFit()

                VStack(spacing: 12) {
                    Text("Your energy is critically low! Get to the kitchen now and restore your energy before it's too late.")
                        .font(GameFont.callout)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        AudioManager.shared.playButtonSound()
                        onDismiss()
                    }) {
                        Text("GOT IT")
                            .font(GameFont.calloutBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: .rect(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 180)
                .padding(.bottom, 16)
            }
            .frame(width: 480)
            .onTapGesture {
                // Block tap-through on card
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
}
