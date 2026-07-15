import SwiftUI

struct GameplayHUDView: View {
    let viewModel: TacticalMapViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackTrigger = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if viewModel.isGameplayActive && !viewModel.isMapPresented {
                MapButton(action: openMap)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .transition(.opacity)
            }

            if viewModel.isMapPresented {
                TacticalMapView(viewModel: viewModel, onClose: closeMap)
                    .transition(mapTransition)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(overlayAnimation, value: viewModel.isMapPresented)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    }

    private var overlayAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.12)
            : .easeInOut(duration: MapDesignTokens.overlayAnimationDuration)
    }

    private var mapTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func openMap() {
        feedbackTrigger += 1
        viewModel.openMap()
    }

    private func closeMap() {
        feedbackTrigger += 1
        viewModel.closeMap()
    }
}
