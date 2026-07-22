#if DEBUG
import Foundation

enum MapGeometryExporter {
    static func jsonData(for configuration: MapGeometryConfiguration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(configuration.sortedForExport())
    }

    static func jsonString(for configuration: MapGeometryConfiguration) throws -> String {
        guard let string = String(data: try jsonData(for: configuration), encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return string + (string.hasSuffix("\n") ? "" : "\n")
    }

    static func swiftCode(for configuration: MapGeometryConfiguration) -> String {
        let value = configuration.sortedForExport()
        return """
        extension MapGeometryConfiguration {
            static var drawingSpaceDefault: MapGeometryConfiguration {
                MapGeometryConfiguration(
                    schemaVersion: \(value.schemaVersion),
                    worldSize: \(size(value.worldSize)),
                    playerVisualRadius: \(number(value.playerVisualRadius)),
                    playerFootprint: MapPlayerFootprintDefinition(
                        centerOffset: \(point(value.playerFootprint.centerOffset)),
                        width: \(number(value.playerFootprint.width)),
                        height: \(number(value.playerFootprint.height)),
                        obstacleRadius: \(number(value.playerFootprint.obstacleRadius))\(bodyObstacleRadiusArg(value.playerFootprint))
                    ),
                    wallThickness: \(number(value.wallThickness)),
                    walkabilityEpsilon: \(number(value.walkabilityEpsilon)),
                    targetClampStep: \(number(value.targetClampStep)),
                    targetClampMaximumRadius: \(number(value.targetClampMaximumRadius)),
                    rooms: [
        \(value.rooms.map { room($0) }.joined(separator: ",\n"))
                    ],
                    corridors: [
        \(value.corridors.map { corridor($0) }.joined(separator: ",\n"))
                    ],
                    walls: [
        \(value.walls.map { wall($0) }.joined(separator: ",\n"))
                    ],
                    doorways: [
        \(value.doorways.map { doorway($0) }.joined(separator: ",\n"))
                    ],
                    blockedAreas: [
        \(value.blockedAreas.map { blockedArea($0) }.joined(separator: ",\n"))
                    ],
                    objects: [
        \(value.objects.map { object($0) }.joined(separator: ",\n"))
                    ],
                    stations: [
        \(value.stations.map { station($0) }.joined(separator: ",\n"))
                    ],
                    spawnPoints: [
        \(value.spawnPoints.map { spawn($0) }.joined(separator: ",\n"))
                    ],
                    checkpoints: [
        \(value.checkpoints.map { checkpoint($0) }.joined(separator: ",\n"))
                    ]
                )
            }
        }
        """
    }

    static func temporaryFile(
        for configuration: MapGeometryConfiguration,
        format: ExportFormat
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            format == .json ? "DrawingSpaceMapGeometry.json" : "DrawingSpaceMapGeometry.swift"
        )
        let data: Data
        switch format {
        case .json: data = try jsonData(for: configuration)
        case .swift: data = Data(swiftCode(for: configuration).utf8)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case json
        case swift
        var id: String { rawValue }
    }

    private static func room(_ value: MapRoomDefinition) -> String {
        line("MapRoomDefinition", [
            "id: \(quoted(value.id))", "name: \(quoted(value.name))", "roomID: \(value.roomID.map { ".\($0.rawValue)" } ?? "nil")",
            "frame: \(rect(value.frame))", "triggerFrame: \(rect(value.triggerFrame))",
            "isWalkable: \(value.isWalkable)", "isRequired: \(value.isRequired)",
            "vertices: \(optionalPoints(value.vertices))", "triggerVertices: \(optionalPoints(value.triggerVertices))"
        ])
    }

    private static func corridor(_ value: MapCorridorDefinition) -> String {
        line("MapCorridorDefinition", ["id: \(quoted(value.id))", "name: \(quoted(value.name))", "frame: \(rect(value.frame))", "isWalkable: \(value.isWalkable)", "isRequired: \(value.isRequired)", "vertices: \(optionalPoints(value.vertices))"])
    }

    private static func wall(_ value: MapWallDefinition) -> String {
        line("MapWallDefinition", ["id: \(quoted(value.id))", "name: \(quoted(value.name))", "frame: \(rect(value.frame))", "rotation: \(number(value.rotationRadians))", "isEnabled: \(value.isEnabled)", "isRequired: \(value.isRequired)", "vertices: \(optionalPoints(value.vertices))"])
    }

    private static func doorway(_ value: MapDoorwayDefinition) -> String {
        line("MapDoorwayDefinition", [
            "id: \(quoted(value.id))", "name: \(quoted(value.name))",
            "doorID: \(value.doorID.map { ".\($0.rawValue)" } ?? "nil")",
            "roomID: \(value.roomID.map { ".\($0.rawValue)" } ?? "nil")",
            "frame: \(rect(value.frame))", "defaultState: .\(value.defaultState.rawValue)",
            "isEnabled: \(value.isEnabled)", "isRequired: \(value.isRequired)",
            "vertices: \(optionalPoints(value.vertices))"
        ])
    }

    private static func blockedArea(_ value: MapBlockedAreaDefinition) -> String {
        line("MapBlockedAreaDefinition", ["id: \(quoted(value.id))", "name: \(quoted(value.name))", "shape: \(shape(value.shape))", "isEnabled: \(value.isEnabled)", "isRequired: \(value.isRequired)"])
    }

    private static func object(_ value: MapObjectDefinition) -> String {
        line("MapObjectDefinition", [
            "id: \(quoted(value.id))", "name: \(quoted(value.name))", "type: .\(value.type.rawValue)",
            "position: \(point(value.position))", "size: \(size(value.size))", "rotation: \(number(value.rotation))",
            "interactionID: \(optionalString(value.interactionID))", "isEnabled: \(value.isEnabled)", "isRequired: \(value.isRequired)",
            "vertices: \(optionalPoints(value.vertices))"
        ])
    }

    private static func station(_ value: MapStationDefinition) -> String {
        line("MapStationDefinition", [
            "id: \(quoted(value.id))", "name: \(quoted(value.name))", "kind: .\(value.kind.rawValue)",
            "roomID: \(value.roomID.map { ".\($0.rawValue)" } ?? "nil")", "position: \(point(value.position))",
            "interactionID: \(optionalString(value.interactionID))", "isEnabled: \(value.isEnabled)", "isRequired: \(value.isRequired)",
            "vertices: \(optionalPoints(value.vertices))"
        ])
    }

    private static func spawn(_ value: MapSpawnPointDefinition) -> String {
        line("MapSpawnPointDefinition", ["id: \(quoted(value.id))", "name: \(quoted(value.name))", "roomID: \(value.roomID.map { ".\($0.rawValue)" } ?? "nil")", "position: \(point(value.position))", "isRequired: \(value.isRequired)"])
    }

    private static func checkpoint(_ value: MapCheckpointDefinition) -> String {
        line("MapCheckpointDefinition", [
            "id: \(quoted(value.id))", "name: \(quoted(value.name))",
            "checkpointID: \(value.checkpointID.map { ".\($0.rawValue)" } ?? "nil")",
            "roomID: \(value.roomID.map { ".\($0.rawValue)" } ?? "nil")",
            "position: \(point(value.position))", "isRequired: \(value.isRequired)"
        ])
    }

    private static func line(_ type: String, _ parameters: [String]) -> String {
        "            \(type)(\(parameters.joined(separator: ", ")))"
    }

    private static func shape(_ value: MapGeometryShape) -> String {
        switch value {
        case let .rectangle(value): ".rectangle(\(rect(value)))"
        case let .polygon(points): ".polygon([\(points.map { point($0) }.joined(separator: ", "))])"
        case let .edgeChain(points): ".edgeChain([\(points.map { point($0) }.joined(separator: ", "))])"
        }
    }

    private static func point(_ value: CodablePoint) -> String {
        "CodablePoint(x: \(number(value.x)), y: \(number(value.y)))"
    }

    private static func size(_ value: CodableSize) -> String {
        "CodableSize(width: \(number(value.width)), height: \(number(value.height)))"
    }

    private static func rect(_ value: CodableRect) -> String {
        "CodableRect(x: \(number(value.x)), y: \(number(value.y)), width: \(number(value.width)), height: \(number(value.height)))"
    }

    private static func optionalString(_ value: String?) -> String { value.map { quoted($0) } ?? "nil" }
    private static func optionalPoints(_ value: [CodablePoint]?) -> String {
        value.map { "[\($0.map { point($0) }.joined(separator: ", "))]" } ?? "nil"
    }
    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = (value * 100).rounded() / 100
        if rounded.rounded() == rounded { return String(Int(rounded)) }
        var output = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        while output.last == "0" { output.removeLast() }
        if output.last == "." { output.removeLast() }
        return output
    }

    private static func bodyObstacleRadiusArg(_ value: MapPlayerFootprintDefinition) -> String {
        guard let r = value.bodyObstacleRadius else { return "" }
        return ",\n                        bodyObstacleRadius: \(number(r))"
    }
}

private extension MapGeometryConfiguration {
    func sortedForExport() -> MapGeometryConfiguration {
        var copy = self
        copy.rooms.sort { $0.id < $1.id }
        copy.corridors.sort { $0.id < $1.id }
        copy.walls.sort { $0.id < $1.id }
        copy.doorways.sort { $0.id < $1.id }
        copy.blockedAreas.sort { $0.id < $1.id }
        copy.objects.sort { $0.id < $1.id }
        copy.stations.sort { $0.id < $1.id }
        copy.spawnPoints.sort { $0.id < $1.id }
        copy.checkpoints.sort { $0.id < $1.id }
        return copy
    }
}
#endif
