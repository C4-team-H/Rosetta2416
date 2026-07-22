import SwiftUI

struct FullMapView: View {
    let viewModel: TacticalMapViewModel
    var viewportTransform = MapViewportTransform.identity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let converter = MapCoordinateConverter(
                worldSize: viewModel.geometryStore.configuration.worldSize.cgSize,
                viewportSize: geometry.size,
                padding: MapDesignTokens.mapPadding
            )
            let surfaceFrame = converter.mapFrame.insetBy(
                dx: -MapDesignTokens.mapPadding,
                dy: -MapDesignTokens.mapPadding
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(
                    cornerRadius: MapDesignTokens.mapCornerRadius,
                    style: .continuous
                )
                    .fill(MapDesignTokens.mapBezel)
                    .frame(width: surfaceFrame.width, height: surfaceFrame.height)
                    .position(x: surfaceFrame.midX, y: surfaceFrame.midY)
                    .shadow(color: MapDesignTokens.ink.opacity(0.88), radius: 0, y: 5)

                RoundedRectangle(cornerRadius: MapDesignTokens.mapCornerRadius - 6)
                    .fill(MapDesignTokens.mapBackground)
                    .frame(
                        width: max(0, surfaceFrame.width - 12),
                        height: max(0, surfaceFrame.height - 12)
                    )
                    .position(x: surfaceFrame.midX, y: surfaceFrame.midY)

                MapBackgroundView(
                    converter: converter,
                    configuration: viewModel.geometryStore.configuration,
                    isFullyRevealed: viewModel.isFullMapRevealed
                )

                ForEach(viewModel.visibleMarkers) { marker in
                    MapMarkerView(marker: marker)
                        .position(converter.mapPosition(from: marker.worldPosition, edgeInset: 15))
                }

                MapPlayerMarkerView(player: viewModel.localPlayer)
                    .position(converter.mapPosition(from: viewModel.localPlayer.worldPosition, edgeInset: 28))

                if let teammate = viewModel.teammate {
                    MapPlayerMarkerView(player: teammate)
                    .position(converter.mapPosition(from: teammate.worldPosition, edgeInset: 28))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.16),
                        value: teammate.worldPosition
                    )
                }

                RoundedRectangle(
                    cornerRadius: MapDesignTokens.mapCornerRadius,
                    style: .continuous
                )
                .strokeBorder(MapDesignTokens.ink, lineWidth: 5)
                .frame(width: surfaceFrame.width, height: surfaceFrame.height)
                .position(x: surfaceFrame.midX, y: surfaceFrame.midY)

                RoundedRectangle(cornerRadius: MapDesignTokens.mapCornerRadius - 7)
                    .strokeBorder(MapDesignTokens.panelShellHighlight.opacity(0.64), lineWidth: 2)
                    .frame(
                        width: max(0, surfaceFrame.width - 12),
                        height: max(0, surfaceFrame.height - 12)
                    )
                    .position(x: surfaceFrame.midX, y: surfaceFrame.midY)

                MapScreenBadge(
                    title: "DECK 01",
                    color: MapDesignTokens.accent
                )
                .position(
                    x: surfaceFrame.minX + 50,
                    y: surfaceFrame.minY + 32
                )

                MapScreenBadge(
                    title: viewModel.isFullMapRevealed ? "LIVE" : "NO SIGNAL",
                    color: viewModel.isFullMapRevealed
                        ? MapDesignTokens.completedMarker
                        : MapDesignTokens.blockedMarker
                )
                .position(
                    x: surfaceFrame.maxX - 54,
                    y: surfaceFrame.minY + 32
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(viewportTransform.scale)
            .offset(viewportTransform.offset)
        }
        .aspectRatio(
            viewModel.geometryStore.configuration.worldSize.width
                / viewModel.geometryStore.configuration.worldSize.height,
            contentMode: .fit
        )
        .frame(minHeight: 180)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tactical station map")
    }
}

private struct MapScreenBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(title)
                .font(GameFont.custom(size: 8, weight: 800))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 16)
        .background(MapDesignTokens.ink.opacity(0.86), in: .capsule)
        .overlay {
            Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}
