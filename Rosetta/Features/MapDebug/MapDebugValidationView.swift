#if DEBUG
import SwiftUI

struct MapDebugValidationView: View {
    let viewModel: MapDebugViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.store.validation.errors.isEmpty && viewModel.store.validation.warnings.isEmpty {
                    ContentUnavailableView("Geometry Valid", systemImage: "checkmark.shield.fill", description: Text("No errors or warnings were found."))
                }
                if !viewModel.store.validation.errors.isEmpty {
                    Section("Errors (\(viewModel.store.validation.errors.count))") {
                        ForEach(viewModel.store.validation.errors) { issue in issueRow(issue, color: .red) }
                    }
                }
                if !viewModel.store.validation.warnings.isEmpty {
                    Section("Warnings (\(viewModel.store.validation.warnings.count))") {
                        ForEach(viewModel.store.validation.warnings) { issue in issueRow(issue, color: .orange) }
                    }
                }
            }
            .navigationTitle("Geometry Validation")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Run Again") { viewModel.store.validateNow() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func issueRow(_ issue: MapGeometryValidationIssue, color: Color) -> some View {
        Button {
            if let elementID = issue.elementIDs.first {
                viewModel.store.selectedElement = MapEditorSelection(elementID)
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(issue.severity.rawValue.uppercased(), systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(issue.message).foregroundStyle(.primary)
                if !issue.elementIDs.isEmpty {
                    Text(issue.elementIDs.map(\.rawValue).joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
