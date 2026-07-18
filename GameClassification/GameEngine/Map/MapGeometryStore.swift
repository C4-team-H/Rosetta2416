import CoreGraphics
import Foundation
import Observation

struct MapGeometryChangeSet: Equatable, Sendable {
    var inserted: Set<MapElementID> = []
    var updated: Set<MapElementID> = []
    var removed: Set<MapElementID> = []
    var isFullReplacement = false

    static let none = MapGeometryChangeSet()
    static let fullReplacement = MapGeometryChangeSet(isFullReplacement: true)

    var categories: Set<MapElementCategory> {
        Set(inserted.map(\.category) + updated.map(\.category) + removed.map(\.category))
    }

    mutating func formUnion(_ other: MapGeometryChangeSet) {
        guard !isFullReplacement else { return }
        if other.isFullReplacement {
            self = .fullReplacement
            return
        }
        inserted.formUnion(other.inserted)
        updated.formUnion(other.updated)
        removed.formUnion(other.removed)
    }
}

protocol MapGeometryApplying: AnyObject {
    func apply(configuration: MapGeometryConfiguration)
    func update(element: MapGeometryElement)
    func remove(elementID: MapElementID)
}

@MainActor
@Observable
final class MapGeometryStore {
    private(set) var configuration: MapGeometryConfiguration
    private(set) var source: MapGeometrySource
    private(set) var revision: Int = 0
    private(set) var isDirty = false
    private(set) var validation: MapGeometryValidationResult = .empty
    private(set) var latestChangeSet: MapGeometryChangeSet = .fullReplacement
    var selectedElement: MapEditorSelection?
    var statusMessage: String?

    private let bundledDefault: MapGeometryConfiguration
    private let history: MapEditorHistory
    private let validator: MapGeometryValidator
    private var transactionStart: MapGeometryConfiguration?

    init(
        configuration: MapGeometryConfiguration? = nil,
        source: MapGeometrySource = .swiftConfiguration,
        history: MapEditorHistory? = nil,
        validator: MapGeometryValidator? = nil
    ) {
        let configuration = configuration ?? .drawingSpaceDefault
        let history = history ?? MapEditorHistory()
        let validator = validator ?? MapGeometryValidator()
        self.configuration = configuration
        bundledDefault = .drawingSpaceDefault
        self.source = source
        self.history = history
        self.validator = validator
        validation = validator.validate(configuration, includeReachability: false)
    }

    var selectedGeometry: MapGeometryElement? {
        selectedElement.flatMap { configuration.element(id: $0.elementID) }
    }

    var orderedElementIDs: [MapElementID] {
        configuration.allElements.map(\.id).sorted {
            if $0.category.rawValue == $1.category.rawValue { return $0.rawValue < $1.rawValue }
            return $0.category.rawValue < $1.category.rawValue
        }
    }

    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    func beginTransaction() {
        if transactionStart == nil { transactionStart = configuration }
    }

    func endTransaction(validate: Bool = true) {
        guard let start = transactionStart else { return }
        transactionStart = nil
        if start != configuration { history.record(start) }
        if validate { validation = validator.validate(configuration) }
    }

    func cancelTransaction() {
        guard let start = transactionStart else { return }
        transactionStart = nil
        replaceConfiguration(start, source: source, recordHistory: false)
    }

    func update(_ element: MapGeometryElement, validate: Bool = true) {
        guard isStructurallyValid(element) else {
            statusMessage = "Invalid number or geometry size"
            return
        }
        recordCurrentIfNeeded()
        configuration.upsert(element)
        publish(changeSet: MapGeometryChangeSet(updated: [element.id]))
        if validate, transactionStart == nil {
            validation = validator.validate(configuration, includeReachability: false)
        }
    }

    func insert(_ element: MapGeometryElement) {
        guard configuration.element(id: element.id) == nil else {
            statusMessage = "ID \(element.id.rawValue) already exists"
            return
        }
        guard isStructurallyValid(element) else {
            statusMessage = "Invalid number or geometry size"
            return
        }
        recordCurrentIfNeeded()
        configuration.upsert(element)
        selectedElement = MapEditorSelection(element.id)
        publish(changeSet: MapGeometryChangeSet(inserted: [element.id]))
        validation = validator.validate(configuration, includeReachability: false)
    }

    @discardableResult
    func remove(_ id: MapElementID) -> Bool {
        guard let element = configuration.element(id: id), !element.isRequired else {
            statusMessage = "Required map elements cannot be deleted"
            return false
        }
        recordCurrentIfNeeded()
        guard configuration.remove(id: id) else { return false }
        if selectedElement?.elementID == id { selectedElement = nil }
        publish(changeSet: MapGeometryChangeSet(removed: [id]))
        validation = validator.validate(configuration, includeReachability: false)
        return true
    }

    @discardableResult
    func duplicate(_ id: MapElementID, offset: CGFloat = 10) -> MapElementID? {
        guard let element = configuration.element(id: id), !element.isRequired else {
            statusMessage = "Required map elements cannot be duplicated"
            return nil
        }
        let newID = uniqueCopyID(for: id)
        guard let copy = element.copy(id: newID.rawValue, offset: CGVector(dx: offset, dy: offset)) else { return nil }
        insert(copy)
        return copy.id
    }

    func moveSelected(to position: CGPoint, grid: MapEditorGridConfiguration, validate: Bool = false) {
        guard let selectedGeometry else { return }
        let target = grid.snapped(position)
        update(selectedGeometry.moved(to: target), validate: validate)
    }

    func resizeSelected(to frame: CGRect, grid: MapEditorGridConfiguration, validate: Bool = false) {
        guard let selectedGeometry else { return }
        var frame = frame.standardized
        frame.origin = grid.snapped(frame.origin)
        frame.size.width = max(10, grid.snapped(frame.size.width))
        frame.size.height = max(10, grid.snapped(frame.size.height))
        guard let resized = selectedGeometry.resized(to: frame) else { return }
        update(resized, validate: validate)
    }

    func updateSelectedName(_ name: String) {
        guard let selectedGeometry else { return }
        update(selectedGeometry.renamed(name.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    func updateSelectedRotation(_ rotation: Double) {
        guard let selectedGeometry, rotation.isFinite else { return }
        update(selectedGeometry.withRotation(rotation))
    }

    func updatePlayerFootprint(
        _ footprint: MapPlayerFootprintDefinition,
        validate: Bool = true
    ) {
        guard isStructurallyValid(footprint) else {
            statusMessage = "Invalid player footprint"
            return
        }
        recordCurrentIfNeeded()
        configuration.playerFootprint = footprint
        publish(changeSet: .fullReplacement)
        if validate, transactionStart == nil {
            validation = validator.validate(configuration, includeReachability: false)
        }
    }

    func selectPrevious() { moveSelection(by: -1) }
    func selectNext() { moveSelection(by: 1) }

    func clearSelection() { selectedElement = nil }

    func undo() {
        guard let previous = history.undo(current: configuration) else { return }
        configuration = previous
        source = .debugDraft
        publish(changeSet: .fullReplacement)
        repairSelection()
        validation = validator.validate(configuration, includeReachability: false)
    }

    func redo() {
        guard let next = history.redo(current: configuration) else { return }
        configuration = next
        source = .debugDraft
        publish(changeSet: .fullReplacement)
        repairSelection()
        validation = validator.validate(configuration, includeReachability: false)
    }

    func resetToBundledDefault() {
        replaceConfiguration(bundledDefault, source: .swiftConfiguration, recordHistory: true)
        statusMessage = "Bundled map restored"
    }

    func replaceConfiguration(
        _ replacement: MapGeometryConfiguration,
        source: MapGeometrySource,
        recordHistory: Bool = true
    ) {
        guard validator.structuralIssues(in: replacement).isEmpty else {
            statusMessage = "Configuration contains invalid structural geometry"
            return
        }
        if recordHistory { history.record(configuration) }
        configuration = replacement
        self.source = source
        publish(changeSet: .fullReplacement)
        repairSelection()
        validation = validator.validate(configuration, includeReachability: false)
    }

    func markSaved(source: MapGeometrySource = .debugDraft) {
        self.source = source
        isDirty = false
        statusMessage = "Map draft saved"
    }

    func validateNow() {
        validation = validator.validate(configuration)
        statusMessage = validation.errors.isEmpty
            ? "Geometry validation completed"
            : "Geometry has \(validation.errors.count) error(s)"
    }

    private func publish(changeSet: MapGeometryChangeSet) {
        revision += 1
        latestChangeSet.formUnion(changeSet)
        isDirty = true
        source = .debugDraft
    }

    func consumePendingChangeSet() -> MapGeometryChangeSet {
        let pending = latestChangeSet
        latestChangeSet = .none
        return pending
    }

    private func recordCurrentIfNeeded() {
        if transactionStart == nil { history.record(configuration) }
    }

    private func moveSelection(by offset: Int) {
        let ids = orderedElementIDs
        guard !ids.isEmpty else { selectedElement = nil; return }
        let currentIndex = selectedElement.flatMap { selection in
            ids.firstIndex(of: selection.elementID)
        } ?? (offset > 0 ? -1 : ids.count)
        let index = (currentIndex + offset + ids.count) % ids.count
        selectedElement = MapEditorSelection(ids[index])
    }

    private func repairSelection() {
        if let selectedElement, configuration.element(id: selectedElement.elementID) == nil {
            self.selectedElement = nil
        }
    }

    private func uniqueCopyID(for id: MapElementID) -> MapElementID {
        var number = 1
        while configuration.element(id: MapElementID(category: id.category, rawValue: "\(id.rawValue)-copy-\(number)")) != nil {
            number += 1
        }
        return MapElementID(category: id.category, rawValue: "\(id.rawValue)-copy-\(number)")
    }

    private func isStructurallyValid(_ element: MapGeometryElement) -> Bool {
        if case let .wall(wall) = element,
           !wall.rotationRadians.isFinite {
            return false
        }
        guard element.freeformPointSets.allSatisfy({ points in
            points.count >= 3 && points.allSatisfy(\.isFinite)
        }) else { return false }
        if let frame = element.worldFrame {
            return frame.origin.x.isFinite && frame.origin.y.isFinite
                && frame.width.isFinite && frame.height.isFinite
                && frame.width > 0 && frame.height > 0
        }
        return element.worldPosition.x.isFinite && element.worldPosition.y.isFinite
    }

    private func isStructurallyValid(_ footprint: MapPlayerFootprintDefinition) -> Bool {
        footprint.centerOffset.isFinite
            && footprint.width.isFinite
            && footprint.height.isFinite
            && footprint.obstacleRadius.isFinite
            && footprint.width > 0
            && footprint.height > 0
            && footprint.obstacleRadius > 0
    }
}

private extension MapGeometryElement {
    func moved(to target: CGPoint) -> MapGeometryElement {
        let delta = CGVector(dx: target.x - worldPosition.x, dy: target.y - worldPosition.y)
        switch self {
        case var .room(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: delta.dx, dy: delta.dy))
            value.triggerFrame = CodableRect(value.triggerFrame.cgRect.offsetBy(dx: delta.dx, dy: delta.dy))
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            value.triggerVertices = offsetPoints(value.triggerVertices, dx: delta.dx, dy: delta.dy)
            return .room(value)
        case var .corridor(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: delta.dx, dy: delta.dy))
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            return .corridor(value)
        case var .wall(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: delta.dx, dy: delta.dy))
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            return .wall(value)
        case var .doorway(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: delta.dx, dy: delta.dy))
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            return .doorway(value)
        case var .blockedArea(value):
            value.shape = value.shape.offsetBy(dx: delta.dx, dy: delta.dy); return .blockedArea(value)
        case var .object(value):
            value.position = CodablePoint(x: target.x, y: target.y)
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            return .object(value)
        case var .station(value):
            value.position = CodablePoint(x: target.x, y: target.y)
            value.vertices = offsetPoints(value.vertices, dx: delta.dx, dy: delta.dy)
            return .station(value)
        case var .spawnPoint(value):
            value.position = CodablePoint(x: target.x, y: target.y); return .spawnPoint(value)
        case var .checkpoint(value):
            value.position = CodablePoint(x: target.x, y: target.y); return .checkpoint(value)
        }
    }

    func resized(to frame: CGRect) -> MapGeometryElement? {
        switch self {
        case var .room(value):
            let old = value.walkableBounds
            let xScale = old.width > 0 ? frame.width / old.width : 1
            let yScale = old.height > 0 ? frame.height / old.height : 1
            let trigger = value.triggerFrame.cgRect
            value.vertices = scaledPoints(value.vertices, from: old, to: frame)
            value.triggerVertices = scaledPoints(value.triggerVertices, from: old, to: frame)
            value.frame = CodableRect(frame)
            if let triggerVertices = validPolygonPoints(value.triggerVertices) {
                value.triggerFrame = CodableRect(pointsBounds(triggerVertices))
            } else {
                value.triggerFrame = CodableRect(CGRect(
                    x: frame.minX + (trigger.minX - old.minX) * xScale,
                    y: frame.minY + (trigger.minY - old.minY) * yScale,
                    width: trigger.width * xScale,
                    height: trigger.height * yScale
                ))
            }
            return .room(value)
        case var .corridor(value):
            value.vertices = scaledPoints(value.vertices, from: value.walkableBounds, to: frame)
            value.frame = CodableRect(frame)
            return .corridor(value)
        case var .wall(value):
            value.vertices = scaledPoints(value.vertices, from: value.rotatedBounds, to: frame)
            value.frame = CodableRect(frame)
            return .wall(value)
        case var .doorway(value):
            value.vertices = scaledPoints(value.vertices, from: value.doorwayBounds, to: frame)
            value.frame = CodableRect(frame)
            return .doorway(value)
        case var .blockedArea(value):
            guard case .rectangle = value.shape else { return nil }
            value.shape = .rectangle(CodableRect(frame)); return .blockedArea(value)
        case var .object(value):
            value.vertices = scaledPoints(value.vertices, from: value.objectBounds, to: frame)
            value.position = CodablePoint(x: frame.midX, y: frame.midY)
            value.size = CodableSize(width: frame.width, height: frame.height)
            return .object(value)
        case var .station(value):
            guard validPolygonPoints(value.vertices) != nil else { return nil }
            value.vertices = scaledPoints(value.vertices, from: value.stationBounds, to: frame)
            value.position = CodablePoint(x: frame.midX, y: frame.midY)
            return .station(value)
        case .spawnPoint, .checkpoint: return nil
        }
    }

    func renamed(_ name: String) -> MapGeometryElement {
        let safeName = name.isEmpty ? self.name : name
        switch self {
        case var .room(value): value.name = safeName; return .room(value)
        case var .corridor(value): value.name = safeName; return .corridor(value)
        case var .wall(value): value.name = safeName; return .wall(value)
        case var .doorway(value): value.name = safeName; return .doorway(value)
        case var .blockedArea(value): value.name = safeName; return .blockedArea(value)
        case var .object(value): value.name = safeName; return .object(value)
        case var .station(value): value.name = safeName; return .station(value)
        case var .spawnPoint(value): value.name = safeName; return .spawnPoint(value)
        case var .checkpoint(value): value.name = safeName; return .checkpoint(value)
        }
    }

    func withRotation(_ rotation: Double) -> MapGeometryElement {
        switch self {
        case var .wall(value):
            if let points = validPolygonPoints(value.vertices) {
                let delta = rotation - value.rotationRadians
                let center = CGPoint(x: value.rotatedBounds.midX, y: value.rotatedBounds.midY)
                value.vertices = points.map {
                    CodablePoint(rotatedPoint($0, around: center, rotation: delta))
                }
            }
            value.rotation = rotation
            return .wall(value)
        case var .object(value):
            if let points = validPolygonPoints(value.vertices) {
                let delta = rotation - value.rotation
                let center = value.position.cgPoint
                value.vertices = points.map {
                    CodablePoint(rotatedPoint($0, around: center, rotation: delta))
                }
            }
            value.rotation = rotation
            return .object(value)
        default:
            return self
        }
    }

    func copy(id: String, offset: CGVector) -> MapGeometryElement? {
        let copy = moved(to: CGPoint(x: worldPosition.x + offset.dx, y: worldPosition.y + offset.dy))
        switch copy {
        case var .corridor(value): value = MapCorridorDefinition(id: id, name: "\(value.name) Copy", frame: value.frame, isWalkable: value.isWalkable, isRequired: false, vertices: value.vertices); return .corridor(value)
        case var .wall(value): value = MapWallDefinition(id: id, name: "\(value.name) Copy", frame: value.frame, rotation: value.rotation, isEnabled: value.isEnabled, isRequired: false, vertices: value.vertices); return .wall(value)
        case var .blockedArea(value): value = MapBlockedAreaDefinition(id: id, name: "\(value.name) Copy", shape: value.shape, isEnabled: value.isEnabled, isRequired: false); return .blockedArea(value)
        case var .object(value): value = MapObjectDefinition(id: id, name: "\(value.name) Copy", type: value.type, position: value.position, size: value.size, rotation: value.rotation, interactionID: nil, isEnabled: value.isEnabled, isRequired: false, vertices: value.vertices); return .object(value)
        case var .station(value): value = MapStationDefinition(id: id, name: "\(value.name) Copy", kind: value.kind, roomID: value.roomID, position: value.position, interactionID: nil, isEnabled: value.isEnabled, isRequired: false, vertices: value.vertices); return .station(value)
        default: return nil
        }
    }
}

private func offsetPoints(
    _ points: [CodablePoint]?,
    dx: CGFloat,
    dy: CGFloat
) -> [CodablePoint]? {
    points?.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) }
}

private func scaledPoints(
    _ points: [CodablePoint]?,
    from source: CGRect,
    to destination: CGRect
) -> [CodablePoint]? {
    guard let points, source.width > 0, source.height > 0 else { return points }
    return points.map { point in
        CodablePoint(
            x: destination.minX + (point.x - source.minX) / source.width * destination.width,
            y: destination.minY + (point.y - source.minY) / source.height * destination.height
        )
    }
}

private extension MapGeometryShape {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> MapGeometryShape {
        switch self {
        case let .rectangle(rect): return .rectangle(CodableRect(rect.cgRect.offsetBy(dx: dx, dy: dy)))
        case let .polygon(points): return .polygon(points.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) })
        case let .edgeChain(points): return .edgeChain(points.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) })
        }
    }
}
