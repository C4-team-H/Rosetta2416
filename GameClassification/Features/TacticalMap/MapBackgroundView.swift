import SwiftUI

struct MapBackgroundView: View {
    let converter: MapCoordinateConverter
    let configuration: MapGeometryConfiguration

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawGrid(in: &context)
                drawWalkableAreas(in: &context)
                drawWalls(in: &context)
            }

            ForEach(configuration.rooms) { room in
                let roomFrame = converter.mapRect(from: room.triggerFrame.cgRect)

                Text(room.name.uppercased())
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(width: max(0, roomFrame.width - 10))
                    .position(x: roomFrame.midX, y: roomFrame.midY)
            }
        }
    }

    private func drawGrid(in context: inout GraphicsContext) {
        guard converter.scale > 0 else { return }

        var path = Path()
        let step = max(10, converter.scale * 100)

        for x in stride(from: converter.mapFrame.minX, through: converter.mapFrame.maxX, by: step) {
            path.move(to: CGPoint(x: x, y: converter.mapFrame.minY))
            path.addLine(to: CGPoint(x: x, y: converter.mapFrame.maxY))
        }
        for y in stride(from: converter.mapFrame.minY, through: converter.mapFrame.maxY, by: step) {
            path.move(to: CGPoint(x: converter.mapFrame.minX, y: y))
            path.addLine(to: CGPoint(x: converter.mapFrame.maxX, y: y))
        }

        context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 0.7)
    }

    private func drawWalkableAreas(in context: inout GraphicsContext) {
        for corridor in configuration.corridors where corridor.isWalkable {
            let rect = converter.mapRect(from: corridor.frame.cgRect)
            let path = Path(roundedRect: rect, cornerRadius: max(2, converter.scale * 18))
            context.fill(path, with: .color(MapDesignTokens.corridorFill))
        }

        for room in configuration.rooms where room.isWalkable {
            let rect = converter.mapRect(from: room.triggerFrame.cgRect)
            let path = Path(roundedRect: rect, cornerRadius: max(3, converter.scale * 24))
            context.fill(path, with: .color(MapDesignTokens.roomFill))
            context.stroke(path, with: .color(.cyan.opacity(0.28)), lineWidth: 1)
        }
    }

    private func drawWalls(in context: inout GraphicsContext) {
        let wallWidth = max(1.5, min(4, converter.scale * 16))

        for wall in configuration.walls where wall.isEnabled {
            let path = Path(converter.mapRect(from: wall.frame.cgRect))
            context.fill(path, with: .color(MapDesignTokens.wall))
            context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: max(0.5, wallWidth / 3))
        }
    }
}
