import SwiftUI

struct MapLegendView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("MAP KEY")
                    .font(GameFont.custom(size: 9, weight: 800))
                    .foregroundStyle(MapDesignTokens.accent)

                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    legendItems
                }

                Grid(alignment: .leading, horizontalSpacing: 7, verticalSpacing: 7) {
                    GridRow {
                        MapLegendItem(
                            title: "You",
                            systemImage: "person.crop.circle.fill",
                            assetImage: "YouIcon",
                            color: MapDesignTokens.localCrew
                        )
                    }
                    GridRow {
                        MapLegendItem(
                            title: "Mission",
                            systemImage: "exclamationmark",
                            color: MapDesignTokens.activeMarker
                        )
                        MapLegendItem(
                            title: "Door",
                            systemImage: "door.left.hand.open",
                            color: MapDesignTokens.unlockedMarker
                        )
                    }
                    GridRow {
                        MapLegendItem(
                            title: "Locked",
                            systemImage: "lock.fill",
                            color: MapDesignTokens.lockedMarker
                        )
                    }
                }
            }
        }
        .padding(10)
        .background(MapDesignTokens.panelWell, in: .rect(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(MapDesignTokens.ink, lineWidth: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map legend")
    }

    @ViewBuilder
    private var legendItems: some View {
        MapLegendItem(
            title: "You",
            systemImage: "person.crop.circle.fill",
            assetImage: "YouIcon",
            color: MapDesignTokens.localCrew
        )
        MapLegendItem(
            title: "Mission",
            systemImage: "exclamationmark",
            color: MapDesignTokens.activeMarker
        )
        MapLegendItem(
            title: "Door",
            systemImage: "door.left.hand.open",
            color: MapDesignTokens.unlockedMarker
        )
        MapLegendItem(
            title: "Locked",
            systemImage: "lock.fill",
            color: MapDesignTokens.lockedMarker
        )
    }

}
