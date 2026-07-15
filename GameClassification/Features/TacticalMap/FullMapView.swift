import SwiftUI

struct FullMapView: View {
    let viewModel: TacticalMapViewModel
    var viewportTransform = MapViewportTransform.identity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let converter = MapCoordinateConverter(
                worldSize: GameMapLayout.worldSize,
                viewportSize: geometry.size,
                padding: MapDesignTokens.mapPadding
            )
            let surfaceFrame = converter.mapFrame.insetBy(
                dx: -MapDesignTokens.mapPadding,
                dy: -MapDesignTokens.mapPadding
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: MapDesignTokens.mapCornerRadius)
                    .fill(MapDesignTokens.mapBackground)
                    .frame(width: surfaceFrame.width, height: surfaceFrame.height)
                    .position(x: surfaceFrame.midX, y: surfaceFrame.midY)

                RoundedRectangle(cornerRadius: MapDesignTokens.mapCornerRadius)
                    .stroke(.cyan.opacity(0.22), lineWidth: 1)
                    .frame(width: surfaceFrame.width, height: surfaceFrame.height)
                    .position(x: surfaceFrame.midX, y: surfaceFrame.midY)

                MapBackgroundView(converter: converter)

                ForEach(viewModel.visibleMarkers) { marker in
                    MapMarkerView(marker: marker)
                        .position(converter.mapPosition(from: marker.worldPosition, edgeInset: 15))
                }

                MapPlayerMarkerView(player: viewModel.localPlayer)
                    .position(converter.mapPosition(from: viewModel.localPlayer.worldPosition, edgeInset: 28))

                if let teammate = viewModel.teammate {
                    MapPlayerMarkerView(
                        player: teammate,
                        connectionState: viewModel.teammateConnectionState
                    )
                    .position(converter.mapPosition(from: teammate.worldPosition, edgeInset: 28))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.16),
                        value: teammate.worldPosition
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(viewportTransform.scale)
            .offset(viewportTransform.offset)
        }
        .frame(minHeight: 180)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Station map")
    }
}
