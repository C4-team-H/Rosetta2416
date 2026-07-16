#if DEBUG
import SwiftUI

struct MapDebugLayerControls: View {
    let viewModel: MapDebugViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("LAYERS", systemImage: "square.3.layers.3d")
                    .font(.caption.bold())
                Spacer()
                Button { viewModel.isShowingLayers = false } label: { Image(systemName: "xmark") }
            }

            layerToggle("Rooms", color: .green, value: bind(\.showRooms))
            layerToggle("Corridors", color: .cyan, value: bind(\.showCorridors))
            layerToggle("Walls", color: .red, value: bind(\.showWalls))
            layerToggle("Doorways", color: .yellow, value: bind(\.showDoorways))
            layerToggle("Blocked", color: Color(red: 1, green: 0, blue: 0.85), value: bind(\.showBlockedAreas))
            layerToggle("Objects", color: .orange, value: bind(\.showObjects))
            layerToggle("Stations", color: .purple, value: bind(\.showStations))
            layerToggle("Spawns", color: .white, value: bind(\.showSpawnPoints))
            layerToggle("Checkpoints", color: .yellow, value: bind(\.showCheckpoints))

            Divider().overlay(.white.opacity(0.2))
            Toggle("Coordinates", isOn: bind(\.showCoordinates))
            Toggle("Grid", isOn: bind(\.showGrid))
            Toggle("Physics", isOn: bind(\.showCollisionBodies))
            Button("Show All") { viewModel.settings.resetVisibility() }
                .font(.caption.bold())
        }
        .font(.caption)
        .toggleStyle(.switch)
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: 210)
        .background(.black.opacity(0.84), in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16)) }
    }

    private func layerToggle(_ title: String, color: Color, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
            }
        }
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<GameDebugSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { viewModel.settings[keyPath: keyPath] = $0 }
        )
    }
}
#endif
