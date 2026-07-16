import Foundation
import Observation

enum DebugAvailability {
    static var isMapEditorAvailable: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

@MainActor
@Observable
final class GameDebugSettings {
    var isMapDebugEnabled: Bool { didSet { persist() } }
    var showRooms: Bool { didSet { persist() } }
    var showCorridors: Bool { didSet { persist() } }
    var showWalls: Bool { didSet { persist() } }
    var showDoorways: Bool { didSet { persist() } }
    var showBlockedAreas: Bool { didSet { persist() } }
    var showObjects: Bool { didSet { persist() } }
    var showStations: Bool { didSet { persist() } }
    var showSpawnPoints: Bool { didSet { persist() } }
    var showCheckpoints: Bool { didSet { persist() } }
    var showCollisionBodies: Bool { didSet { persist() } }
    var showCoordinates: Bool { didSet { persist() } }
    var showGrid: Bool { didSet { persist() } }
    var gridSize: Double { didSet { persist() } }
    var snapToGrid: Bool { didSet { persist() } }
    var editorMode: MapEditorMode { didSet { persist() } }

    #if DEBUG
    private let defaults: UserDefaults
    private var isRestoring = false
    #endif

    init(defaults: UserDefaults = .standard) {
        #if DEBUG
        self.defaults = defaults
        let launchEnabled = ProcessInfo.processInfo.arguments.contains("-ShipMapDebug")
        isMapDebugEnabled = launchEnabled || defaults.bool(forKey: Key.enabled)
        showRooms = defaults.object(forKey: Key.rooms) as? Bool ?? true
        showCorridors = defaults.object(forKey: Key.corridors) as? Bool ?? true
        showWalls = defaults.object(forKey: Key.walls) as? Bool ?? true
        showDoorways = defaults.object(forKey: Key.doors) as? Bool ?? true
        showBlockedAreas = defaults.object(forKey: Key.blocked) as? Bool ?? true
        showObjects = defaults.object(forKey: Key.objects) as? Bool ?? true
        showStations = defaults.object(forKey: Key.stations) as? Bool ?? true
        showSpawnPoints = defaults.object(forKey: Key.spawns) as? Bool ?? true
        showCheckpoints = defaults.object(forKey: Key.checkpoints) as? Bool ?? true
        showCollisionBodies = defaults.object(forKey: Key.physics) as? Bool ?? launchEnabled
        showCoordinates = defaults.object(forKey: Key.coordinates) as? Bool ?? true
        showGrid = defaults.object(forKey: Key.grid) as? Bool ?? true
        gridSize = max(1, defaults.object(forKey: Key.gridSize) as? Double ?? 10)
        snapToGrid = defaults.object(forKey: Key.snap) as? Bool ?? true
        editorMode = launchEnabled
            ? .navigate
            : MapEditorMode(rawValue: defaults.string(forKey: Key.mode) ?? "navigate") ?? .navigate
        #else
        isMapDebugEnabled = false
        showRooms = false
        showCorridors = false
        showWalls = false
        showDoorways = false
        showBlockedAreas = false
        showObjects = false
        showStations = false
        showSpawnPoints = false
        showCheckpoints = false
        showCollisionBodies = false
        showCoordinates = false
        showGrid = false
        gridSize = 10
        snapToGrid = false
        editorMode = .inspect
        #endif
    }

    var simulationMode: MapDebugSimulationMode {
        editorMode == .testCollision ? .collisionTesting : .editing
    }

    var isEditingGameplaySuspended: Bool {
        DebugAvailability.isMapEditorAvailable && isMapDebugEnabled && simulationMode == .editing
    }

    var allowsCollisionTesting: Bool {
        DebugAvailability.isMapEditorAvailable && isMapDebugEnabled && simulationMode == .collisionTesting
    }

    var gridConfiguration: MapEditorGridConfiguration {
        MapEditorGridConfiguration(gridSize: gridSize, snapToGrid: snapToGrid)
    }

    func resetVisibility() {
        showRooms = true
        showCorridors = true
        showWalls = true
        showDoorways = true
        showBlockedAreas = true
        showObjects = true
        showStations = true
        showSpawnPoints = true
        showCheckpoints = true
        showCoordinates = true
        showGrid = true
    }

    private func persist() {
        #if DEBUG
        guard !isRestoring else { return }
        defaults.set(isMapDebugEnabled, forKey: Key.enabled)
        defaults.set(showRooms, forKey: Key.rooms)
        defaults.set(showCorridors, forKey: Key.corridors)
        defaults.set(showWalls, forKey: Key.walls)
        defaults.set(showDoorways, forKey: Key.doors)
        defaults.set(showBlockedAreas, forKey: Key.blocked)
        defaults.set(showObjects, forKey: Key.objects)
        defaults.set(showStations, forKey: Key.stations)
        defaults.set(showSpawnPoints, forKey: Key.spawns)
        defaults.set(showCheckpoints, forKey: Key.checkpoints)
        defaults.set(showCollisionBodies, forKey: Key.physics)
        defaults.set(showCoordinates, forKey: Key.coordinates)
        defaults.set(showGrid, forKey: Key.grid)
        defaults.set(max(1, gridSize), forKey: Key.gridSize)
        defaults.set(snapToGrid, forKey: Key.snap)
        defaults.set(editorMode.rawValue, forKey: Key.mode)
        #endif
    }

    private enum Key {
        static let prefix = "DrawingSpace.MapDebug."
        static let enabled = prefix + "enabled"
        static let rooms = prefix + "rooms"
        static let corridors = prefix + "corridors"
        static let walls = prefix + "walls"
        static let doors = prefix + "doors"
        static let blocked = prefix + "blocked"
        static let objects = prefix + "objects"
        static let stations = prefix + "stations"
        static let spawns = prefix + "spawns"
        static let checkpoints = prefix + "checkpoints"
        static let physics = prefix + "physics"
        static let coordinates = prefix + "coordinates"
        static let grid = prefix + "grid"
        static let gridSize = prefix + "gridSize"
        static let snap = prefix + "snap"
        static let mode = prefix + "mode"
    }
}
