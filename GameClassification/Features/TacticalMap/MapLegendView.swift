import SwiftUI

struct MapLegendView: View {
    let showsTeammate: Bool
    let teammateConnectionState: TeammateConnectionState

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
                            color: MapDesignTokens.localCrew
                        )
                        teammateLegend
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
                            color: MapDesignTokens.doorway
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
            color: MapDesignTokens.localCrew
        )
        teammateLegend
        MapLegendItem(
            title: "Mission",
            systemImage: "exclamationmark",
            color: MapDesignTokens.activeMarker
        )
        MapLegendItem(
            title: "Door",
            systemImage: "door.left.hand.open",
            color: MapDesignTokens.doorway
        )
        MapLegendItem(
            title: "Locked",
            systemImage: "lock.fill",
            color: MapDesignTokens.lockedMarker
        )
    }

    private var teammateLegend: some View {
        MapLegendItem(
            title: teammateTitle,
            systemImage: teammateConnectionState == .connected ? "person.fill" : "wifi.slash",
            color: teammateConnectionState == .connected
                ? MapDesignTokens.teammateCrew
                : MapDesignTokens.blockedMarker
        )
        .opacity(showsTeammate ? 1 : 0.45)
    }

    private var teammateTitle: String {
        guard showsTeammate else { return "Crew hidden" }

        return switch teammateConnectionState {
        case .connected:
            "Crew"
        case .reconnecting:
            "Crew reconnecting"
        case .disconnected:
            "Crew offline"
        }
    }
}
