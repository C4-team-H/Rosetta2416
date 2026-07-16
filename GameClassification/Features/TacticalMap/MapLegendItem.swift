import SwiftUI

struct MapLegendItem: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(color)
            .font(GameFont.caption1Bold)
            .lineLimit(1)
    }
}
