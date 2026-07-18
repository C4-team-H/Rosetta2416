import SwiftUI

struct MapBackgroundView: View {
    let converter: MapCoordinateConverter
    let configuration: MapGeometryConfiguration

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawGrid(in: &context)
                drawHull(in: &context)
                drawWalkableAreas(in: &context)
                drawObjects(in: &context)
                drawWalls(in: &context)
                drawDoorways(in: &context)
            }

            ForEach(configuration.rooms) { room in
                let roomFrame = converter.mapRect(from: room.roomTriggerBounds)

                Text(room.name)
                    .font(GameFont.caption1Bold)
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
            guard let path = closedPath(for: corridor.walkablePoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.corridorFill))
        }

        for room in configuration.rooms where room.isWalkable {
            guard let path = closedPath(for: room.walkablePoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.roomFill))
            context.stroke(path, with: .color(.cyan.opacity(0.28)), lineWidth: 1)
        }
    }

    private func drawHull(in context: inout GraphicsContext) {
        for area in configuration.blockedAreas where area.isEnabled {
            guard let path = path(for: area.shape) else { continue }
            context.fill(path, with: .color(MapDesignTokens.hullFill))
            context.stroke(path, with: .color(MapDesignTokens.hullStroke), lineWidth: 1)
        }
    }

    private func drawObjects(in context: inout GraphicsContext) {
        for object in configuration.objects where object.isEnabled && object.type == .obstacle {
            guard let path = closedPath(for: object.objectPoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.objectFill))
            context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 0.7)
        }
    }

    private func drawWalls(in context: inout GraphicsContext) {
        let wallWidth = max(1.5, min(4, converter.scale * 16))

        for wall in configuration.walls where wall.isEnabled {
            guard let path = closedPath(for: wall.rotatedCorners) else { continue }
            context.fill(path, with: .color(MapDesignTokens.wall))
            context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: max(0.5, wallWidth / 3))
        }
    }

    private func drawDoorways(in context: inout GraphicsContext) {
        for doorway in configuration.doorways where doorway.isEnabled {
            guard let path = closedPath(for: doorway.doorwayPoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.doorway))
        }
    }

    private func path(for shape: MapGeometryShape) -> Path? {
        switch shape {
        case let .rectangle(rect):
            return Path(converter.mapRect(from: rect.cgRect))
        case let .polygon(points), let .edgeChain(points):
            return closedPath(for: points.map(\.cgPoint))
        }
    }

    private func closedPath(for worldPoints: [CGPoint]) -> Path? {
        let points = converter.mapPoints(from: worldPoints)
        guard points.count >= 3, let firstPoint = points.first else { return nil }

        var path = Path()
        path.move(to: firstPoint)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}
