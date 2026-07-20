import Foundation
import SwiftUI

struct LowEnergyAlertOverlay: View {
    let session: GameSessionState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Block tap-through to underlying views; only the GOT IT button dismisses
                }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(GameFont.title1)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("WARNING")
                            .font(GameFont.title3Bold)
                            .foregroundStyle(.red)

                        Text("LOW ENERGY")
                            .font(GameFont.bodyBold)
                            .foregroundStyle(.red.opacity(0.85))
                    }
                }

                Divider().overlay(Color.red.opacity(0.4))

                Text("Your energy is critically low at \(Int(session.energy))%! Get to the kitchen now and restore your energy before it's too late.")
                    .font(GameFont.callout)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(action: {
                    AudioManager.shared.playButtonSound()
                    onDismiss()
                }) {
                    Text("GOT IT")
                        .font(GameFont.calloutBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(
                Color(red: 0.12, green: 0.05, blue: 0.05).opacity(0.94),
                in: .rect(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.red, .orange.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
            .shadow(color: .red.opacity(0.5), radius: 24, x: 0, y: 0)
            .padding(24)
            .onTapGesture {
                // Prevent tap on the card from passing to backdrop or underlying views
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
}
