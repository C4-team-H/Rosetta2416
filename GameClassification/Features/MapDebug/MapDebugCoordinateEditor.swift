#if DEBUG
import SwiftUI

struct MapDebugCoordinateEditor: View {
    let title: String
    @Binding var value: Double
    var isEnabled = true
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption2.bold()).foregroundStyle(.white.opacity(0.65))
                Spacer()
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 112)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(onCommit)
                    .disabled(!isEnabled)
            }
            HStack(spacing: 4) {
                ForEach([-10.0, -1.0, 1.0, 10.0], id: \.self) { delta in
                    Button(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))") {
                        value += delta
                        onCommit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(!isEnabled)
                }
            }
        }
    }
}
#endif
