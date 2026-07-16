#if DEBUG
import SwiftUI

struct MapDebugToolbar: View {
    let viewModel: MapDebugViewModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MapEditorMode.allCases) { mode in
                        Button {
                            viewModel.settings.editorMode = mode
                        } label: {
                            Label(mode.title, systemImage: mode.symbol)
                                .font(.caption.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.settings.editorMode == mode ? .black : .white)
                        .background(
                            viewModel.settings.editorMode == mode ? Color.cyan : Color.white.opacity(0.10),
                            in: .rect(cornerRadius: 8)
                        )
                    }
                }
            }

            Divider().overlay(.white.opacity(0.2)).frame(height: 28)

            Button { viewModel.store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!viewModel.store.canUndo)
            Button { viewModel.store.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!viewModel.store.canRedo)
            Button { viewModel.isShowingLayers.toggle() } label: { Image(systemName: "square.3.layers.3d") }
            Button { viewModel.validateGeometry() } label: { Image(systemName: "checkmark.shield") }
            Button { viewModel.isShowingExport = true } label: { Image(systemName: "square.and.arrow.up") }
            Button { viewModel.isShowingSettings = true } label: { Image(systemName: "gearshape") }
            Button {
                viewModel.settings.isMapDebugEnabled = false
            } label: {
                Image(systemName: "xmark")
            }
        }
        .buttonStyle(MapDebugIconButtonStyle())
        .padding(10)
        .background(.black.opacity(0.86), in: .rect(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(.cyan.opacity(0.35)) }
    }
}

private struct MapDebugIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(minWidth: 30, minHeight: 30)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

private extension MapEditorMode {
    var title: String {
        switch self {
        case .navigate: "Pan"
        case .inspect: "Inspect"
        case .select: "Select"
        case .move: "Move"
        case .resize: "Resize"
        case .editNodes: "Nodes"
        case .create: "Create"
        case .delete: "Delete"
        case .testCollision: "Test"
        }
    }

    var symbol: String {
        switch self {
        case .navigate: "hand.draw"
        case .inspect: "info.circle"
        case .select: "cursorarrow"
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .resize: "arrow.up.left.and.arrow.down.right"
        case .editNodes: "point.3.connected.trianglepath.dotted"
        case .create: "plus.square"
        case .delete: "trash"
        case .testCollision: "figure.walk"
        }
    }
}
#endif
