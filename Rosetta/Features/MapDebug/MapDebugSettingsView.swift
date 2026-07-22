#if DEBUG
import SwiftUI

struct MapDebugSettingsView: View {
    let viewModel: MapDebugViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsReset = false
    @State private var confirmsDraftDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Developer Tools") {
                    Toggle("Enable Map Debugging", isOn: binding(\.isMapDebugEnabled))
                    Toggle("Show SpriteKit Physics", isOn: binding(\.showCollisionBodies))
                    Toggle("Show Coordinate Labels", isOn: binding(\.showCoordinates))
                }
                Section("Grid") {
                    Toggle("Show Grid", isOn: binding(\.showGrid))
                    Toggle("Snap to Grid", isOn: binding(\.snapToGrid))
                    HStack {
                        Text("Grid Size")
                        Spacer()
                        TextField("10", value: Binding(
                            get: { viewModel.settings.gridSize },
                            set: { viewModel.settings.gridSize = max(1, $0) }
                        ), format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    }
                }
                Section("Draft") {
                    Button("Save Draft") { viewModel.saveDraft() }
                    Button("Load Draft") { viewModel.loadDraft() }
                    Button("Reset to Bundled Default", role: .destructive) {
                        confirmsReset = true
                    }
                    Button("Delete Saved Draft", role: .destructive) {
                        confirmsDraftDeletion = true
                    }
                }
            }
            .navigationTitle("Map Debug Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset all geometry to the Swift default?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset to Bundled Default", role: .destructive) { viewModel.store.resetToBundledDefault() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete the saved debug draft?", isPresented: $confirmsDraftDeletion, titleVisibility: .visible) {
                Button("Delete Saved Draft", role: .destructive) { viewModel.deleteDraft() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<GameDebugSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { viewModel.settings[keyPath: keyPath] = $0 }
        )
    }
}
#endif
