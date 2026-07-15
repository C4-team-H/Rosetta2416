import SwiftUI

struct MapLegendItem: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(color)
            .font(.caption)
            .bold()
            .lineLimit(1)
    }
}
