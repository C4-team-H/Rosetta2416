import SwiftUI

struct MapPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.68),
                value: configuration.isPressed
            )
    }
}
