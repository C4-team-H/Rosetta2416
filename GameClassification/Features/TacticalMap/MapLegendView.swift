import SwiftUI

struct MapLegendView: View {
    let showsTeammate: Bool
    let teammateConnectionState: TeammateConnectionState

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                legendItems
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    MapLegendItem(title: "You", systemImage: "location.fill", color: .cyan)
                    teammateLegend
                }
                GridRow {
                    MapLegendItem(title: "Mission", systemImage: "exclamationmark.square.fill", color: .yellow)
                    MapLegendItem(title: "Door", systemImage: "door.left.hand.open", color: .mint)
                }
                GridRow {
                    MapLegendItem(title: "Locked", systemImage: "lock.fill", color: .gray)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map legend")
    }

    @ViewBuilder
    private var legendItems: some View {
        MapLegendItem(title: "You", systemImage: "location.fill", color: .cyan)
        teammateLegend
        MapLegendItem(title: "Mission", systemImage: "exclamationmark.square.fill", color: .yellow)
        MapLegendItem(title: "Door", systemImage: "door.left.hand.open", color: .mint)
        MapLegendItem(title: "Locked", systemImage: "lock.fill", color: .gray)
    }

    private var teammateLegend: some View {
        MapLegendItem(
            title: teammateTitle,
            systemImage: teammateConnectionState == .connected ? "person.fill" : "wifi.slash",
            color: teammateConnectionState == .connected ? .orange : .red
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
