import SwiftUI

struct MapBackgroundView: View {
    let converter: MapCoordinateConverter
    let configuration: MapGeometryConfiguration
    let isFullyRevealed: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawGrid(in: &context)
                drawScannerGuides(in: &context)
                if isFullyRevealed {
                    drawHull(in: &context)
                    drawWalkableAreas(in: &context)
                    drawObjects(in: &context)
                    drawWalls(in: &context)
                    drawDoorways(in: &context)
                }
            }

            if isFullyRevealed {
                ForEach(configuration.rooms) { room in
                    let roomFrame = converter.mapRect(from: room.roomTriggerBounds)

                    Text(room.name.uppercased())
                        .font(GameFont.custom(size: 10, weight: 800))
                        .foregroundStyle(MapDesignTokens.mapLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: max(12, roomFrame.width - 14))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            MapDesignTokens.mapLabelBackground,
                            in: .rect(cornerRadius: 6)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                        }
                        .position(x: roomFrame.midX, y: roomFrame.midY)
                }
            } else {
                MapSignalUnavailableView()
                    .frame(width: min(280, max(0, converter.mapFrame.width - 36)))
                    .position(x: converter.mapFrame.midX, y: converter.mapFrame.midY)
            }
        }
    }

    private func drawGrid(in context: inout GraphicsContext) {
        guard converter.scale > 0 else { return }

        let minorStep = max(16, converter.scale * 180)
        let majorStep = minorStep * 4
        var minorPath = Path()
        var majorPath = Path()

        for x in stride(
            from: converter.mapFrame.minX,
            through: converter.mapFrame.maxX,
            by: minorStep
        ) {
            minorPath.move(to: CGPoint(x: x, y: converter.mapFrame.minY))
            minorPath.addLine(to: CGPoint(x: x, y: converter.mapFrame.maxY))
        }
        for y in stride(
            from: converter.mapFrame.minY,
            through: converter.mapFrame.maxY,
            by: minorStep
        ) {
            minorPath.move(to: CGPoint(x: converter.mapFrame.minX, y: y))
            minorPath.addLine(to: CGPoint(x: converter.mapFrame.maxX, y: y))
        }

        for x in stride(
            from: converter.mapFrame.minX,
            through: converter.mapFrame.maxX,
            by: majorStep
        ) {
            majorPath.move(to: CGPoint(x: x, y: converter.mapFrame.minY))
            majorPath.addLine(to: CGPoint(x: x, y: converter.mapFrame.maxY))
        }
        for y in stride(
            from: converter.mapFrame.minY,
            through: converter.mapFrame.maxY,
            by: majorStep
        ) {
            majorPath.move(to: CGPoint(x: converter.mapFrame.minX, y: y))
            majorPath.addLine(to: CGPoint(x: converter.mapFrame.maxX, y: y))
        }

        context.stroke(minorPath, with: .color(MapDesignTokens.mapGrid), lineWidth: 0.7)
        context.stroke(majorPath, with: .color(MapDesignTokens.mapGridMajor), lineWidth: 1.2)
    }

    private func drawScannerGuides(in context: inout GraphicsContext) {
        let frame = converter.mapFrame
        guard frame.width > 0, frame.height > 0 else { return }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        var crosshair = Path()
        crosshair.move(to: CGPoint(x: frame.minX, y: center.y))
        crosshair.addLine(to: CGPoint(x: frame.maxX, y: center.y))
        crosshair.move(to: CGPoint(x: center.x, y: frame.minY))
        crosshair.addLine(to: CGPoint(x: center.x, y: frame.maxY))
        context.stroke(
            crosshair,
            with: .color(MapDesignTokens.mapGridMajor.opacity(0.62)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 8])
        )

        let diameter = min(frame.width, frame.height) * 0.58
        let ring = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        context.stroke(
            Path(ellipseIn: ring),
            with: .color(MapDesignTokens.mapGridMajor.opacity(0.55)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 7])
        )
    }

    private func drawWalkableAreas(in context: inout GraphicsContext) {
        for corridor in configuration.corridors where corridor.isWalkable {
            guard let path = closedPath(for: corridor.walkablePoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.corridorFill))
            context.stroke(path, with: .color(MapDesignTokens.ink), lineWidth: 5)
            context.stroke(path, with: .color(MapDesignTokens.corridorStroke), lineWidth: 2)
        }

        for room in configuration.rooms where room.isWalkable {
            guard let path = closedPath(for: room.walkablePoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.roomFill))
            context.stroke(path, with: .color(MapDesignTokens.ink), lineWidth: 6)
            context.stroke(path, with: .color(MapDesignTokens.roomStroke), lineWidth: 2.4)
        }
    }

    private func drawHull(in context: inout GraphicsContext) {
        for area in configuration.blockedAreas where area.isEnabled {
            guard let path = path(for: area.shape) else { continue }
            context.fill(path, with: .color(MapDesignTokens.hullFill))
            context.stroke(path, with: .color(MapDesignTokens.ink), lineWidth: 5)
            context.stroke(path, with: .color(MapDesignTokens.hullStroke), lineWidth: 2)
        }
    }

    private func drawObjects(in context: inout GraphicsContext) {
        for object in configuration.objects where object.isEnabled && object.type == .obstacle {
            guard let path = closedPath(for: object.objectPoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.objectFill))
            context.stroke(path, with: .color(MapDesignTokens.ink), lineWidth: 3)
            context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
        }
    }

    private func drawWalls(in context: inout GraphicsContext) {
        let wallWidth = max(1.5, min(4, converter.scale * 16))

        for wall in configuration.walls where wall.isEnabled {
            guard let path = closedPath(for: wall.rotatedCorners) else { continue }
            context.fill(path, with: .color(MapDesignTokens.wall))
            context.stroke(path, with: .color(MapDesignTokens.roomStroke), lineWidth: max(0.75, wallWidth / 2))
        }
    }

    private func drawDoorways(in context: inout GraphicsContext) {
        for doorway in configuration.doorways where doorway.isEnabled {
            guard let path = closedPath(for: doorway.doorwayPoints) else { continue }
            context.fill(path, with: .color(MapDesignTokens.doorway))
            context.stroke(path, with: .color(MapDesignTokens.ink), lineWidth: 2.5)
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

private struct MapSignalUnavailableView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.slash.fill")
                .font(GameFont.custom(size: 26, weight: 800))
                .foregroundStyle(MapDesignTokens.doorway)

            Text("SHIP SCAN OFFLINE")
                .font(GameFont.custom(size: 14, weight: 800))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Restore engine power to 10% to reveal the deck layout.")
                .font(GameFont.custom(size: 10, weight: 600))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(MapDesignTokens.panelWell.opacity(0.92), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(MapDesignTokens.ink, lineWidth: 3)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 48, height: 3)
                .padding(.top, 6)
        }
        .accessibilityElement(children: .combine)
    }
}
