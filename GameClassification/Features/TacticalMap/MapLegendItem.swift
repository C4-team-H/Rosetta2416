import SwiftUI

struct MapLegendItem: View {
    let title: String
    let systemImage: String
    var assetImage: String?
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            legendIcon
                .frame(width: 20, height: 20)
                .background(color, in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(MapDesignTokens.ink, lineWidth: 2)
                }

            Text(title)
                .font(GameFont.custom(size: 10, weight: 700))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(MapDesignTokens.mapBezel.opacity(0.72), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var legendIcon: some View {
        if let assetImage {
            Image(assetImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(4)
        } else {
            Image(systemName: systemImage)
                .font(GameFont.custom(size: 9, weight: 800))
                .foregroundStyle(MapDesignTokens.ink)
        }
    }
}
