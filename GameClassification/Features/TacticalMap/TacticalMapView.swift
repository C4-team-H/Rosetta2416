import SwiftUI

struct TacticalMapView: View {
    let viewModel: TacticalMapViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            MapOverlayBackdrop()

            VStack(spacing: MapDesignTokens.contentSpacing) {
                MapOverlayHeader(
                    isMapRevealed: viewModel.isFullMapRevealed,
                    onClose: onClose
                )

                FullMapView(viewModel: viewModel)
                    .layoutPriority(1)

                MapLegendView(
                    showsTeammate: viewModel.showsTeammateOnMap,
                    teammateConnectionState: viewModel.teammateConnectionState
                )
            }
            .foregroundStyle(.white)
            .padding(MapDesignTokens.panelPadding)
            .frame(maxWidth: 960, maxHeight: 720)
            .background {
                RoundedRectangle(
                    cornerRadius: MapDesignTokens.panelCornerRadius,
                    style: .continuous
                )
                .fill(MapDesignTokens.panelShell)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: MapDesignTokens.panelCornerRadius,
                    style: .continuous
                )
                .strokeBorder(MapDesignTokens.ink, lineWidth: 5)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: MapDesignTokens.panelCornerRadius - 7,
                    style: .continuous
                )
                .strokeBorder(MapDesignTokens.panelInnerStroke, lineWidth: 2)
                .padding(7)
            }
//            .overlay {
//                MapConsoleRivets()
//                    .padding(11)
//                    .allowsHitTesting(false)
//            }
            .safeAreaPadding(10)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct MapOverlayBackdrop: View {
    var body: some View {
        MapDesignTokens.backdrop
            .overlay {
                Canvas { context, size in
                    var path = Path()
                    let spacing: CGFloat = 46
                    for startX in stride(
                        from: -size.height,
                        through: size.width,
                        by: spacing
                    ) {
                        path.move(to: CGPoint(x: startX, y: 0))
                        path.addLine(to: CGPoint(x: startX + size.height, y: size.height))
                    }
                    context.stroke(
                        path,
                        with: .color(MapDesignTokens.backdropLine),
                        lineWidth: 1
                    )

                    let ringDiameter = min(size.width, size.height) * 0.82
                    let ringRect = CGRect(
                        x: (size.width - ringDiameter) / 2,
                        y: (size.height - ringDiameter) / 2,
                        width: ringDiameter,
                        height: ringDiameter
                    )
                    context.stroke(
                        Path(ellipseIn: ringRect),
                        with: .color(MapDesignTokens.backdropLine.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 2, dash: [9, 12])
                    )
                }
            }
            .overlay { Color.black.opacity(0.18) }
            .ignoresSafeArea()
    }
}

private struct MapConsoleRivets: View {
    var body: some View {
        VStack {
            HStack {
                MapConsoleRivet()
                Spacer()
                MapConsoleRivet()
            }
            Spacer()
            HStack {
                MapConsoleRivet()
                Spacer()
                MapConsoleRivet()
            }
        }
    }
}

private struct MapConsoleRivet: View {
    var body: some View {
        Circle()
            .fill(MapDesignTokens.rivet)
            .frame(width: 10, height: 10)
            .overlay {
                Capsule()
                    .fill(MapDesignTokens.ink.opacity(0.7))
                    .frame(width: 6, height: 1.5)
                    .rotationEffect(.degrees(-35))
            }
            .overlay {
                Circle().stroke(MapDesignTokens.ink, lineWidth: 2)
            }
    }
}
