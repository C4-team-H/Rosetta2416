import SwiftUI

struct PauseMenuOverlay: View {
    let onKeepPlaying: () -> Void
    let onMainMenu: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            let popupWidth = proxy.size.width
            let popupHeight = popupWidth * 0.75 // 4:3 aspect ratio of the image asset (2752x2064)
            let buttonWidth = popupWidth * 0.22
            
            ZStack {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Block tap-through to underlying views
                    }
                
                ZStack {
                    Image("PausePopUp")
                        .resizable()
                        .scaledToFit()
                        .frame(width: popupWidth, height: popupHeight)
                        .allowsHitTesting(false)
                    
                    VStack {
                        Button(action: {
                            AudioManager.shared.playButtonSound()
                            onKeepPlaying()
                        }) {
                            Image("KeepPlayingButton")
                                .resizable()
                                .scaledToFit()
                                .frame(width: buttonWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PauseScaleButtonStyle())
                        .accessibilityLabel("Keep playing")
                        
                        Button(action: {
                            AudioManager.shared.playButtonSound()
                            onMainMenu()
                        }) {
                            Image("LeavingButton")
                                .resizable()
                                .scaledToFit()
                                .frame(width: buttonWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PauseScaleButtonStyle())
                        .accessibilityLabel("Leave to main menu")
                    }
                    .frame(width: popupWidth, height: popupHeight)
                    .padding(.top, popupHeight * 0.4)
                    .padding(.bottom, popupHeight * 0.03)
                }
                .frame(width: popupWidth, height: popupHeight)
                .offset(y: -36)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
}

private struct PauseScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Pause Menu Overlay", traits: .landscapeLeft) {
    PauseMenuOverlay(
        onKeepPlaying: {},
        onMainMenu: {}
    )
}
