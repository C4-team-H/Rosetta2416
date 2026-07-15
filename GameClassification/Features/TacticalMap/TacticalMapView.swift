import SwiftUI

struct TacticalMapView: View {
    let viewModel: TacticalMapViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Color.black.opacity(0.62)
                }
                .ignoresSafeArea()

            VStack(spacing: MapDesignTokens.contentSpacing) {
                MapOverlayHeader(onClose: onClose)

                FullMapView(viewModel: viewModel)
                    .layoutPriority(1)

                MapLegendView(
                    showsTeammate: viewModel.showsTeammateOnMap,
                    teammateConnectionState: viewModel.teammateConnectionState
                )
            }
            .foregroundStyle(.white)
            .padding(MapDesignTokens.panelPadding)
            .frame(maxWidth: 920, maxHeight: 700)
            .background {
                RoundedRectangle(cornerRadius: MapDesignTokens.panelCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: MapDesignTokens.panelCornerRadius)
                            .fill(Color(red: 0.035, green: 0.055, blue: 0.09).opacity(0.82))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: MapDesignTokens.panelCornerRadius)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 24, y: 12)
            .safeAreaPadding(12)
        }
        .accessibilityAddTraits(.isModal)
    }
}
