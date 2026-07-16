#if DEBUG
import SwiftUI

struct MapDebugExportView: View {
    let viewModel: MapDebugViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var format: MapGeometryExporter.ExportFormat = .json
    @State private var pendingAction: PendingAction?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Format", selection: $format) {
                    Text("JSON").tag(MapGeometryExporter.ExportFormat.json)
                    Text("Swift").tag(MapGeometryExporter.ExportFormat.swift)
                }
                .pickerStyle(.segmented)
                .onChange(of: format, initial: true) { _, newValue in viewModel.prepareExport(newValue) }

                TextEditor(text: Bindable(viewModel).exportText)
                    .font(.caption.monospaced())
                    .padding(6)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)) }

                if !viewModel.store.validation.errors.isEmpty {
                    Label("Export contains \(viewModel.store.validation.errors.count) validation error(s).", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button(format == .json ? "Copy JSON" : "Copy Swift Code") { performOrConfirm(.copy(format)) }
                    Button("Share File") { performOrConfirm(.share(format)) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export Map Geometry")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog(
                "Geometry has validation errors. Export anyway?",
                isPresented: Binding(
                    get: { pendingAction != nil },
                    set: { if !$0 { pendingAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Export Anyway") {
                    if let pendingAction { perform(pendingAction) }
                    pendingAction = nil
                }
                Button("Cancel", role: .cancel) { pendingAction = nil }
            }
        }
    }

    private func performOrConfirm(_ action: PendingAction) {
        if viewModel.store.validation.errors.isEmpty {
            perform(action)
        } else {
            pendingAction = action
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case let .copy(format): viewModel.copyExport(format)
        case let .share(format): viewModel.shareExport(format)
        }
    }

    private enum PendingAction {
        case copy(MapGeometryExporter.ExportFormat)
        case share(MapGeometryExporter.ExportFormat)
    }
}

struct MapDebugShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
