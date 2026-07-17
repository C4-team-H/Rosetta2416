#if DEBUG
import SwiftUI

struct MapDebugInspectorView: View {
    let viewModel: MapDebugViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("INSPECTOR", systemImage: "slider.horizontal.3")
                    .font(.caption.bold())
                Spacer()
                Button { viewModel.isShowingInspector = false } label: { Image(systemName: "xmark") }
            }

            if viewModel.settings.editorMode == .create {
                creationPicker
            }

            if viewModel.settings.editorMode == .addNode {
                Label(
                    "Select a room, corridor, wall, doorway, blocked area, object, or station, then tap one of its edges to insert a new node.",
                    systemImage: "plus.circle"
                )
                .font(.caption2)
                .foregroundStyle(.cyan)
            }

            if viewModel.settings.editorMode == .deleteNode {
                Label(
                    "Tap a numbered node on a room, corridor, wall, doorway, blocked area, object, or station to delete it. Every shape keeps at least three nodes.",
                    systemImage: "minus.circle"
                )
                .font(.caption2)
                .foregroundStyle(.red)
            }

            if let element = viewModel.selectedElement {
                MapDebugSelectedElementEditor(viewModel: viewModel, element: element)
                    .id(element.id)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "cursorarrow.click",
                    description: Text("Tap geometry on the map or use Previous / Next.")
                )
                .frame(minHeight: 180)
            }

            HStack {
                Button { viewModel.store.selectPrevious() } label: { Image(systemName: "chevron.left") }
                Button("Clear") { viewModel.store.clearSelection() }
                Button { viewModel.store.selectNext() } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.bordered)

            HStack {
                Button("Duplicate") { viewModel.duplicateSelected() }
                    .disabled(viewModel.selectedElement?.isRequired != false)
                Button("Delete", role: .destructive) {
                    viewModel.pendingDelete = viewModel.selectedElement?.id
                }
                .disabled(viewModel.selectedElement?.isRequired != false)
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: 320)
        .background(.black.opacity(0.86), in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16)) }
    }

    private var creationPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CREATE ELEMENT").font(.caption2.bold()).foregroundStyle(.cyan)
            Picker("Category", selection: Bindable(viewModel).selectedCreationCategory) {
                ForEach(MapElementCategory.debugShapeCreationCases, id: \.self) { category in
                    Text(category.debugTitle).tag(category)
                }
            }
            .pickerStyle(.menu)
            Text("Drag on the map to create a new \(viewModel.selectedCreationCategory.debugTitle.lowercased()).")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct MapDebugSelectedElementEditor: View {
    let viewModel: MapDebugViewModel
    let element: MapGeometryElement

    @State private var name: String
    @State private var x: Double
    @State private var y: Double
    @State private var width: Double
    @State private var height: Double
    @State private var rotationDegrees: Double

    init(viewModel: MapDebugViewModel, element: MapGeometryElement) {
        self.viewModel = viewModel
        self.element = element
        let frame = element.worldFrame
        _name = State(initialValue: element.name)
        _x = State(initialValue: Double(frame?.minX ?? element.worldPosition.x))
        _y = State(initialValue: Double(frame?.minY ?? element.worldPosition.y))
        _width = State(initialValue: Double(frame?.width ?? 0))
        _height = State(initialValue: Double(frame?.height ?? 0))
        if case let .wall(wall) = element {
            _rotationDegrees = State(initialValue: wall.rotationRadians * 180 / .pi)
        } else if case let .object(object) = element {
            _rotationDegrees = State(initialValue: object.rotation * 180 / .pi)
        } else {
            _rotationDegrees = State(initialValue: 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(element.id.rawValue).font(.caption.monospaced().bold()).foregroundStyle(.cyan)
                Text(element.id.category.debugTitle.uppercased()).font(.caption2.bold()).foregroundStyle(.white.opacity(0.55))

                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.store.updateSelectedName(name) }

                MapDebugCoordinateEditor(title: "X", value: $x, onCommit: applyFrame)
                MapDebugCoordinateEditor(title: "Y", value: $y, onCommit: applyFrame)
                MapDebugCoordinateEditor(title: "Width", value: $width, isEnabled: element.worldFrame != nil, onCommit: applyFrame)
                MapDebugCoordinateEditor(title: "Height", value: $height, isEnabled: element.worldFrame != nil, onCommit: applyFrame)
                MapDebugCoordinateEditor(title: "Rotation °", value: $rotationDegrees, isEnabled: isRotatable, onCommit: applyRotation)

                elementOptions
            }
        }
        .frame(maxHeight: 460)
    }

    @ViewBuilder
    private var elementOptions: some View {
        switch element {
        case let .object(object):
            VStack(alignment: .leading) {
                Picker("Type", selection: Binding(
                    get: { object.type },
                    set: { newType in
                        var changed = object
                        changed.type = newType
                        viewModel.store.update(.object(changed))
                    }
                )) {
                    ForEach(MapObjectType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                enabledToggle(object.isEnabled) { value in
                    var changed = object; changed.isEnabled = value
                    viewModel.store.update(.object(changed))
                }
            }
        case let .room(room):
            Toggle("Walkable", isOn: Binding(
                get: { room.isWalkable },
                set: { value in var changed = room; changed.isWalkable = value; viewModel.store.update(.room(changed)) }
            ))
        case let .corridor(corridor):
            Toggle("Walkable", isOn: Binding(
                get: { corridor.isWalkable },
                set: { value in var changed = corridor; changed.isWalkable = value; viewModel.store.update(.corridor(changed)) }
            ))
        case let .wall(wall):
            VStack(alignment: .leading, spacing: 6) {
                enabledToggle(wall.isEnabled) { value in
                    var changed = wall; changed.isEnabled = value
                    viewModel.store.update(.wall(changed))
                }
                if viewModel.settings.editorMode == .editNodes {
                    Label("Drag any numbered corner independently for a freeform wall.", systemImage: "hand.draw")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
        case let .doorway(doorway):
            VStack(alignment: .leading) {
                enabledToggle(doorway.isEnabled) { value in
                    var changed = doorway; changed.isEnabled = value
                    viewModel.store.update(.doorway(changed))
                }
                Picker("Default State", selection: Binding(
                    get: { doorway.defaultState },
                    set: { state in
                        var changed = doorway; changed.defaultState = state
                        viewModel.store.update(.doorway(changed))
                    }
                )) {
                    Text("Open").tag(DoorState.open)
                    Text("Closed").tag(DoorState.closed)
                    Text("Locked").tag(DoorState.locked)
                }
            }
        case let .blockedArea(area):
            enabledToggle(area.isEnabled) { value in
                var changed = area; changed.isEnabled = value
                viewModel.store.update(.blockedArea(changed))
            }
        case let .station(station):
            VStack(alignment: .leading) {
                enabledToggle(station.isEnabled) { value in
                    var changed = station; changed.isEnabled = value
                    viewModel.store.update(.station(changed))
                }
                LabeledContent("Interactive", value: station.interactionID == nil ? "Unbound" : "Bound")
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private func enabledToggle(_ value: Bool, update: @escaping (Bool) -> Void) -> some View {
        Toggle("Enabled", isOn: Binding(get: { value }, set: update))
    }

    private var isRotatable: Bool {
        switch element {
        case .wall, .object: true
        default: false
        }
    }

    private func applyFrame() {
        guard x.isFinite, y.isFinite else { return }
        if element.worldFrame != nil {
            guard width.isFinite, height.isFinite, width > 0, height > 0 else { return }
            viewModel.store.resizeSelected(
                to: CGRect(x: x, y: y, width: width, height: height),
                grid: MapEditorGridConfiguration(gridSize: 1, snapToGrid: false)
            )
        } else {
            viewModel.store.moveSelected(
                to: CGPoint(x: x, y: y),
                grid: MapEditorGridConfiguration(gridSize: 1, snapToGrid: false)
            )
        }
    }

    private func applyRotation() {
        guard rotationDegrees.isFinite else { return }
        viewModel.store.updateSelectedRotation(rotationDegrees * .pi / 180)
    }
}

#endif
