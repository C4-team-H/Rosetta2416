#if DEBUG
import CoreGraphics
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class MapDebugViewModel {
    let store: MapGeometryStore
    let settings: GameDebugSettings
    let converter: MapEditorCoordinateConverter
    let repository: MapGeometryRepository?
    let sessionState: GameSessionState

    var cursorWorldPosition: CGPoint?
    var selectedCreationCategory: MapElementCategory = .wall
    var createPreviewFrame: CGRect?
    var activeResizeHandle: MapResizeHandle?
    var activeVertexIndex: Int?
    var selectedVertexIndex: Int?
    var pendingDelete: MapElementID?
    var isShowingSettings = false
    var isShowingLayers = true
    var isShowingInspector = true
    var isShowingValidation = false
    var isShowingExport = false
    var exportText = ""
    var shareURL: URL?
    var errorMessage: String?

    var onResetPlayerToSpawn: (() -> Void)?
    var onRebuildCollision: (() -> Void)?

    private var dragStartWorld: CGPoint?
    private var dragOriginalElement: MapGeometryElement?
    private var createStartWorld: CGPoint?
    private var lastHitScreenPoint: CGPoint?
    private var lastHitCandidateIDs: [MapElementID] = []
    private var lastHitIndex = 0

    init(
        store: MapGeometryStore,
        settings: GameDebugSettings,
        converter: MapEditorCoordinateConverter,
        repository: MapGeometryRepository?,
        sessionState: GameSessionState
    ) {
        self.store = store
        self.settings = settings
        self.converter = converter
        self.repository = repository
        self.sessionState = sessionState
    }

    var grid: MapEditorGridConfiguration { settings.gridConfiguration }
    var selectedElement: MapGeometryElement? { store.selectedGeometry }

    var statusTitle: String {
        if settings.editorMode == .testCollision { return "COLLISION TEST MODE" }
        if settings.isMapDebugEnabled { return "MAP EDIT MODE" }
        return "MAP DEBUG ENABLED"
    }

    var visibleElements: [MapGeometryElement] {
        store.configuration.allElements.filter { element in
            switch element.id.category {
            case .room: settings.showRooms
            case .corridor: settings.showCorridors
            case .wall: settings.showWalls
            case .doorway: settings.showDoorways
            case .blockedArea: settings.showBlockedAreas
            case .object: settings.showObjects
            case .missionStation, .foodStation: settings.showStations
            case .spawnPoint: settings.showSpawnPoints
            case .checkpoint: settings.showCheckpoints
            }
        }
    }

    func tap(screenPoint: CGPoint) {
        guard let world = converter.screenToWorld(screenPoint) else { return }
        cursorWorldPosition = world
        if settings.editorMode == .create,
           isPointCategory(selectedCreationCategory) {
            createPointElement(category: selectedCreationCategory, at: grid.snapped(world))
            return
        }
        if settings.editorMode == .editNodes,
           let vertexIndex = vertexIndex(at: screenPoint) {
            selectedVertexIndex = vertexIndex
            return
        }
        guard let hit = cycledHitTest(screenPoint: screenPoint) else {
            selectedVertexIndex = nil
            store.clearSelection()
            return
        }
        if store.selectedElement?.elementID != hit.id {
            selectedVertexIndex = nil
        }
        store.selectedElement = MapEditorSelection(hit.id)
        if settings.editorMode == .delete {
            pendingDelete = hit.id
        }
    }

    func beginDrag(screenPoint: CGPoint) {
        guard let world = converter.screenToWorld(screenPoint) else { return }
        cursorWorldPosition = world

        if settings.editorMode == .create {
            guard !isPointCategory(selectedCreationCategory) else { return }
            createStartWorld = grid.snapped(world)
            createPreviewFrame = CGRect(origin: grid.snapped(world), size: .zero)
            return
        }

        if let selectedElement,
           settings.editorMode == .editNodes
            || (settings.editorMode == .resize && selectedElement.supportsFreeformVertexEditing),
           let vertexIndex = vertexIndex(at: screenPoint) {
            activeVertexIndex = vertexIndex
            selectedVertexIndex = vertexIndex
            dragStartWorld = world
            dragOriginalElement = selectedElement
            store.beginTransaction()
            return
        }

        if settings.editorMode == .resize,
           let handle = resizeHandle(at: screenPoint),
           let selectedElement {
            activeResizeHandle = handle
            dragStartWorld = world
            dragOriginalElement = selectedElement
            store.beginTransaction()
            return
        }

        if store.selectedGeometry == nil,
           let hit = hitTest(screenPoint: screenPoint) {
            store.selectedElement = MapEditorSelection(hit.id)
        }

        guard settings.editorMode == .move, let selectedElement = store.selectedGeometry else { return }
        dragStartWorld = world
        dragOriginalElement = selectedElement
        store.beginTransaction()
    }

    func updateDrag(screenPoint: CGPoint) {
        guard let world = converter.screenToWorld(screenPoint) else { return }
        cursorWorldPosition = world

        if settings.editorMode == .create, let start = createStartWorld {
            let end = grid.snapped(world)
            createPreviewFrame = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            return
        }

        guard let start = dragStartWorld, let original = dragOriginalElement else { return }
        let delta = CGVector(dx: world.x - start.x, dy: world.y - start.y)
        if settings.editorMode == .move {
            store.update(original.movedForEditor(by: delta, grid: grid), validate: false)
        } else if settings.editorMode == .resize || settings.editorMode == .editNodes,
                  let activeVertexIndex {
            store.update(
                original.updatingVertexForEditor(
                    at: activeVertexIndex,
                    to: grid.snapped(world)
                ),
                validate: false
            )
        } else if settings.editorMode == .resize,
                  let handle = activeResizeHandle,
                  let originalFrame = original.worldFrame {
            let frame = resizedFrame(
                originalFrame,
                handle: handle,
                worldPoint: grid.snapped(world),
                rotation: original.editorRotation
            )
            store.selectedElement = MapEditorSelection(original.id)
            store.resizeSelected(to: frame, grid: grid, validate: false)
        }
    }

    func endDrag(screenPoint: CGPoint) {
        if settings.editorMode == .create {
            if let frame = createPreviewFrame, frame.width >= 10, frame.height >= 10 {
                createRectangleElement(category: selectedCreationCategory, frame: frame)
            }
            createStartWorld = nil
            createPreviewFrame = nil
            return
        }

        if dragOriginalElement != nil { store.endTransaction(validate: true) }
        dragStartWorld = nil
        dragOriginalElement = nil
        activeResizeHandle = nil
        activeVertexIndex = nil
    }

    func deletePendingElement() {
        guard let pendingDelete else { return }
        _ = store.remove(pendingDelete)
        self.pendingDelete = nil
    }

    func duplicateSelected() {
        guard let id = store.selectedElement?.elementID else { return }
        _ = store.duplicate(id, offset: settings.gridSize)
    }

    func rebuildCollision() {
        store.replaceConfiguration(store.configuration, source: store.source, recordHistory: false)
        onRebuildCollision?()
        store.statusMessage = "Collision rebuild queued"
    }

    func validateGeometry() {
        store.validateNow()
        isShowingValidation = true
    }

    func saveDraft() {
        guard let repository else { errorMessage = "Debug draft repository is unavailable"; return }
        do {
            try repository.save(store.configuration)
            store.markSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDraft() {
        guard let repository else { errorMessage = "Debug draft repository is unavailable"; return }
        do {
            guard let configuration = try repository.load() else {
                errorMessage = "No saved map draft was found"
                return
            }
            store.replaceConfiguration(configuration, source: .debugDraft)
            store.markSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDraft() {
        do {
            try repository?.deleteSavedConfiguration()
            store.statusMessage = "Saved map draft deleted"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareExport(_ format: MapGeometryExporter.ExportFormat) {
        do {
            switch format {
            case .json: exportText = try MapGeometryExporter.jsonString(for: store.configuration)
            case .swift: exportText = MapGeometryExporter.swiftCode(for: store.configuration)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyExport(_ format: MapGeometryExporter.ExportFormat) {
        prepareExport(format)
        UIPasteboard.general.string = exportText
        store.statusMessage = format == .json ? "JSON copied" : "Swift configuration copied"
    }

    func shareExport(_ format: MapGeometryExporter.ExportFormat) {
        do {
            shareURL = try MapGeometryExporter.temporaryFile(for: store.configuration, format: format)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func panCamera(screenTranslation: CGSize) {
        converter.panCamera(
            screenTranslation: screenTranslation,
            worldSize: store.configuration.worldSize.cgSize
        )
    }

    func zoomCamera(multiplier: CGFloat) {
        converter.zoomCamera(
            multiplier: multiplier,
            worldSize: store.configuration.worldSize.cgSize
        )
    }

    var cameraZoomLevel: CGFloat { converter.cameraZoomLevel }

    var cameraZoomRange: ClosedRange<CGFloat> {
        (1 / MapEditorCoordinateConverter.maximumCameraScale)...(1 / MapEditorCoordinateConverter.minimumCameraScale)
    }

    func setCameraZoomLevel(_ zoomLevel: CGFloat) {
        converter.setCameraZoomLevel(
            zoomLevel,
            worldSize: store.configuration.worldSize.cgSize
        )
    }

    func hitTest(screenPoint: CGPoint) -> MapGeometryElement? {
        hitCandidates(screenPoint: screenPoint).first
    }

    private func cycledHitTest(screenPoint: CGPoint) -> MapGeometryElement? {
        let candidates = hitCandidates(screenPoint: screenPoint)
        let ids = candidates.map(\.id)
        guard !candidates.isEmpty else {
            lastHitScreenPoint = nil
            lastHitCandidateIDs = []
            lastHitIndex = 0
            return nil
        }
        if let previousPoint = lastHitScreenPoint,
           distance(previousPoint, screenPoint) <= 24,
           ids == lastHitCandidateIDs {
            lastHitIndex = (lastHitIndex + 1) % candidates.count
        } else {
            lastHitIndex = 0
        }
        lastHitScreenPoint = screenPoint
        lastHitCandidateIDs = ids
        return candidates[lastHitIndex]
    }

    private func hitCandidates(screenPoint: CGPoint) -> [MapGeometryElement] {
        guard let world = converter.screenToWorld(screenPoint) else { return [] }
        let tolerance = worldTolerance(at: screenPoint)
        let candidates = visibleElements.filter { element in
            if let points = element.freeformVertices {
                let path = CGMutablePath()
                if let first = points.first {
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                    path.closeSubpath()
                }
                return path.contains(world)
                    || element.worldFrame?.insetBy(dx: -tolerance, dy: -tolerance).contains(world) == true
            }
            if let rotatedFrame = element.rotatedEditorFrame {
                return pointInRotatedRectangle(
                    world,
                    frame: rotatedFrame.frame,
                    center: rotatedFrame.center,
                    rotation: rotatedFrame.rotation,
                    tolerance: tolerance
                )
            }
            if let frame = element.worldFrame {
                return frame.insetBy(dx: -tolerance, dy: -tolerance).contains(world)
            }
            return hypot(element.worldPosition.x - world.x, element.worldPosition.y - world.y) <= tolerance * 1.5
        }
        return candidates.sorted { lhs, rhs in
            let leftPriority = hitPriority(lhs.id.category)
            let rightPriority = hitPriority(rhs.id.category)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            let leftArea = lhs.worldFrame.map { $0.width * $0.height } ?? 0
            let rightArea = rhs.worldFrame.map { $0.width * $0.height } ?? 0
            return leftArea < rightArea
        }
    }

    func resizeHandle(at screenPoint: CGPoint) -> MapResizeHandle? {
        guard let selected = store.selectedGeometry,
              selected.supportsEightHandleResize else { return nil }
        return handlePoints(for: selected).min { lhs, rhs in
            distance(lhs.value, screenPoint) < distance(rhs.value, screenPoint)
        }.flatMap { distance($0.value, screenPoint) <= 28 ? $0.key : nil }
    }

    func vertexScreenPoints(for element: MapGeometryElement) -> [CGPoint] {
        element.editorVertices.compactMap { converter.worldToScreen($0) }
    }

    private func vertexIndex(at screenPoint: CGPoint) -> Int? {
        guard let selected = store.selectedGeometry, !selected.editorVertices.isEmpty else { return nil }
        return vertexScreenPoints(for: selected).enumerated().min {
            distance($0.element, screenPoint) < distance($1.element, screenPoint)
        }.flatMap { distance($0.element, screenPoint) <= 28 ? $0.offset : nil }
    }

    func handlePoints(for frame: CGRect) -> [MapResizeHandle: CGPoint] {
        [
            .topLeft: CGPoint(x: frame.minX, y: frame.minY),
            .top: CGPoint(x: frame.midX, y: frame.minY),
            .topRight: CGPoint(x: frame.maxX, y: frame.minY),
            .left: CGPoint(x: frame.minX, y: frame.midY),
            .right: CGPoint(x: frame.maxX, y: frame.midY),
            .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY),
            .bottom: CGPoint(x: frame.midX, y: frame.maxY),
            .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        ]
    }

    func handlePoints(for element: MapGeometryElement) -> [MapResizeHandle: CGPoint] {
        guard let frame = element.worldFrame else { return [:] }
        guard let rotated = element.rotatedEditorFrame else {
            guard let screenFrame = converter.screenRect(from: frame) else { return [:] }
            return handlePoints(for: screenFrame)
        }

        let localPoints: [MapResizeHandle: CGPoint] = [
            .topLeft: CGPoint(x: frame.minX, y: frame.maxY),
            .top: CGPoint(x: frame.midX, y: frame.maxY),
            .topRight: CGPoint(x: frame.maxX, y: frame.maxY),
            .left: CGPoint(x: frame.minX, y: frame.midY),
            .right: CGPoint(x: frame.maxX, y: frame.midY),
            .bottomLeft: CGPoint(x: frame.minX, y: frame.minY),
            .bottom: CGPoint(x: frame.midX, y: frame.minY),
            .bottomRight: CGPoint(x: frame.maxX, y: frame.minY)
        ]
        return localPoints.reduce(into: [:]) { result, pair in
            let world = rotateEditorPoint(pair.value, around: rotated.center, rotation: rotated.rotation)
            result[pair.key] = converter.worldToScreen(world)
        }
    }

    private func createRectangleElement(category: MapElementCategory, frame: CGRect) {
        let id = uniqueID(for: category)
        let codableFrame = CodableRect(frame.standardized)
        let element: MapGeometryElement?
        switch category {
        case .room:
            element = .room(MapRoomDefinition(id: id, name: "Debug Room", roomID: nil, frame: codableFrame, triggerFrame: codableFrame, isWalkable: true, isRequired: false))
        case .corridor:
            element = .corridor(MapCorridorDefinition(id: id, name: "Debug Corridor", frame: codableFrame, isWalkable: true, isRequired: false))
        case .wall:
            element = .wall(MapWallDefinition(id: id, name: "Debug Wall", frame: codableFrame, isEnabled: true, isRequired: false))
        case .doorway:
            element = .doorway(MapDoorwayDefinition(id: id, name: "Debug Doorway", doorID: nil, roomID: nil, frame: codableFrame, defaultState: .closed, isEnabled: true, isRequired: false))
        case .blockedArea:
            element = .blockedArea(MapBlockedAreaDefinition(id: id, name: "Debug Blocked Area", shape: .rectangle(codableFrame), isEnabled: true, isRequired: false))
        case .object:
            element = .object(MapObjectDefinition(id: id, name: "Debug Object", type: .obstacle, position: CodablePoint(x: frame.midX, y: frame.midY), size: CodableSize(width: frame.width, height: frame.height), rotation: 0, interactionID: nil, isEnabled: true, isRequired: false))
        case .missionStation, .foodStation, .spawnPoint, .checkpoint:
            element = nil
        }
        if let element { store.insert(element) }
    }

    private func createPointElement(category: MapElementCategory, at point: CGPoint) {
        let id = uniqueID(for: category)
        let position = CodablePoint(point)
        let element: MapGeometryElement?
        switch category {
        case .missionStation:
            element = .station(MapStationDefinition(id: id, name: "Unbound Mission Station", kind: .mission, roomID: nil, position: position, interactionID: nil, isEnabled: true, isRequired: false))
        case .foodStation:
            element = .station(MapStationDefinition(id: id, name: "Debug Food Station", kind: .food, roomID: nil, position: position, interactionID: nil, isEnabled: true, isRequired: false))
        case .spawnPoint:
            element = .spawnPoint(MapSpawnPointDefinition(id: id, name: "Debug Spawn", roomID: nil, position: position, isRequired: false))
        case .checkpoint:
            element = .checkpoint(MapCheckpointDefinition(id: id, name: "Debug Checkpoint", checkpointID: nil, roomID: nil, position: position, isRequired: false))
        default: element = nil
        }
        if let element { store.insert(element) }
    }

    private func uniqueID(for category: MapElementCategory) -> String {
        let prefix = "debug-\(category.rawValue)"
        var counter = 1
        while store.configuration.allElements.contains(where: { $0.id.rawValue == "\(prefix)-\(counter)" }) {
            counter += 1
        }
        return "\(prefix)-\(counter)"
    }

    private func isPointCategory(_ category: MapElementCategory) -> Bool {
        [.missionStation, .foodStation, .spawnPoint, .checkpoint].contains(category)
    }

    private func resizedFrame(
        _ frame: CGRect,
        handle: MapResizeHandle,
        worldPoint: CGPoint,
        rotation: Double
    ) -> CGRect {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let localPoint = rotateEditorPoint(worldPoint, around: center, rotation: -rotation)
        var minX = frame.minX
        var maxX = frame.maxX
        var minY = frame.minY
        var maxY = frame.maxY
        if [.topLeft, .left, .bottomLeft].contains(handle) { minX = min(localPoint.x, maxX - 10) }
        if [.topRight, .right, .bottomRight].contains(handle) { maxX = max(localPoint.x, minX + 10) }
        if [.topLeft, .top, .topRight].contains(handle) { maxY = max(localPoint.y, minY + 10) }
        if [.bottomLeft, .bottom, .bottomRight].contains(handle) { minY = min(localPoint.y, maxY - 10) }

        let localCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let worldCenter = rotateEditorPoint(localCenter, around: center, rotation: rotation)
        return CGRect(
            x: worldCenter.x - (maxX - minX) / 2,
            y: worldCenter.y - (maxY - minY) / 2,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func worldTolerance(at point: CGPoint) -> CGFloat {
        guard let a = converter.screenToWorld(point),
              let b = converter.screenToWorld(CGPoint(x: point.x + 24, y: point.y)) else { return 30 }
        return max(8, hypot(a.x - b.x, a.y - b.y))
    }

    private func hitPriority(_ category: MapElementCategory) -> Int {
        switch category {
        case .missionStation, .foodStation, .spawnPoint, .checkpoint: 0
        case .doorway, .wall, .object: 1
        case .blockedArea: 2
        case .room: 3
        case .corridor: 4
        }
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

private extension MapGeometryElement {
    var editorRotation: Double {
        switch self {
        case let .wall(value): value.rotationRadians
        case let .object(value): value.rotation
        default: 0
        }
    }

    var rotatedEditorFrame: (frame: CGRect, center: CGPoint, rotation: Double)? {
        guard freeformVertices == nil else { return nil }
        guard let frame = worldFrame, abs(editorRotation) > 0.000_1 else { return nil }
        return (frame, worldPosition, editorRotation)
    }

    var supportsEightHandleResize: Bool {
        if case let .blockedArea(area) = self,
           case .rectangle = area.shape { return true }
        if case .blockedArea = self { return false }
        return worldFrame != nil
    }

    var supportsFreeformVertexEditing: Bool {
        guard case let .blockedArea(area) = self else { return false }
        return switch area.shape {
        case .polygon, .edgeChain: true
        case .rectangle: false
        }
    }

    var editorVertices: [CGPoint] {
        switch self {
        case let .room(room):
            return room.walkablePoints
        case let .corridor(corridor):
            return corridor.walkablePoints
        case let .wall(wall):
            return wall.rotatedCorners
        case let .doorway(doorway):
            return doorway.doorwayPoints
        case let .blockedArea(area):
            switch area.shape {
            case let .rectangle(rect): return rectangleEditorVertices(frame: rect.cgRect)
            case let .polygon(points), let .edgeChain(points): return points.map(\.cgPoint)
            }
        case let .object(object):
            return object.objectPoints
        default:
            return []
        }
    }

    func updatingVertexForEditor(at index: Int, to point: CGPoint) -> MapGeometryElement {
        switch self {
        case var .room(room):
            var points = room.walkablePoints
            guard points.indices.contains(index) else { return self }
            let delta = CGVector(dx: point.x - points[index].x, dy: point.y - points[index].y)
            points[index] = point
            var triggerPoints = room.roomTriggerPoints
            if triggerPoints.indices.contains(index) {
                triggerPoints[index] = CGPoint(
                    x: triggerPoints[index].x + delta.dx,
                    y: triggerPoints[index].y + delta.dy
                )
            }
            room.vertices = points.map { CodablePoint($0) }
            room.triggerVertices = triggerPoints.map { CodablePoint($0) }
            room.frame = CodableRect(pointsBounds(points))
            room.triggerFrame = CodableRect(pointsBounds(triggerPoints))
            return .room(room)
        case var .corridor(corridor):
            var points = corridor.walkablePoints
            guard points.indices.contains(index) else { return self }
            points[index] = point
            corridor.vertices = points.map { CodablePoint($0) }
            corridor.frame = CodableRect(pointsBounds(points))
            return .corridor(corridor)
        case var .wall(wall):
            var points = wall.rotatedCorners
            guard points.indices.contains(index) else { return self }
            points[index] = point
            wall.vertices = points.map { CodablePoint($0) }
            wall.frame = CodableRect(pointsBounds(points))
            return .wall(wall)
        case var .doorway(doorway):
            var points = doorway.doorwayPoints
            guard points.indices.contains(index) else { return self }
            points[index] = point
            doorway.vertices = points.map { CodablePoint($0) }
            doorway.frame = CodableRect(pointsBounds(points))
            return .doorway(doorway)
        case var .blockedArea(area):
            switch area.shape {
            case let .rectangle(rect):
                guard let frame = frameByMovingCorner(
                    rect.cgRect,
                    index: index,
                    to: point
                ) else { return self }
                area.shape = .rectangle(CodableRect(frame))
            case var .polygon(points):
                guard points.indices.contains(index) else { return self }
                points[index] = CodablePoint(point)
                area.shape = .polygon(points)
            case var .edgeChain(points):
                guard points.indices.contains(index) else { return self }
                points[index] = CodablePoint(point)
                area.shape = .edgeChain(points)
            }
            return .blockedArea(area)
        case var .object(object):
            var points = object.objectPoints
            guard points.indices.contains(index) else { return self }
            points[index] = point
            let bounds = pointsBounds(points)
            object.vertices = points.map { CodablePoint($0) }
            object.position = CodablePoint(x: bounds.midX, y: bounds.midY)
            object.size = CodableSize(width: bounds.width, height: bounds.height)
            return .object(object)
        default:
            return self
        }
    }

    func movedForEditor(by delta: CGVector, grid: MapEditorGridConfiguration) -> MapGeometryElement {
        let target = grid.snapped(CGPoint(x: worldPosition.x + delta.dx, y: worldPosition.y + delta.dy))
        let adjusted = CGVector(dx: target.x - worldPosition.x, dy: target.y - worldPosition.y)
        switch self {
        case var .room(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: adjusted.dx, dy: adjusted.dy))
            value.triggerFrame = CodableRect(value.triggerFrame.cgRect.offsetBy(dx: adjusted.dx, dy: adjusted.dy))
            value.vertices = value.vertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            value.triggerVertices = value.triggerVertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            return .room(value)
        case var .corridor(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: adjusted.dx, dy: adjusted.dy))
            value.vertices = value.vertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            return .corridor(value)
        case var .wall(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: adjusted.dx, dy: adjusted.dy))
            value.vertices = value.vertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            return .wall(value)
        case var .doorway(value):
            value.frame = CodableRect(value.frame.cgRect.offsetBy(dx: adjusted.dx, dy: adjusted.dy))
            value.vertices = value.vertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            return .doorway(value)
        case var .blockedArea(value): value.shape = value.shape.editorOffset(dx: adjusted.dx, dy: adjusted.dy); return .blockedArea(value)
        case var .object(value):
            value.position = CodablePoint(target)
            value.vertices = value.vertices?.map { CodablePoint(x: $0.x + adjusted.dx, y: $0.y + adjusted.dy) }
            return .object(value)
        case var .station(value): value.position = CodablePoint(target); return .station(value)
        case var .spawnPoint(value): value.position = CodablePoint(target); return .spawnPoint(value)
        case var .checkpoint(value): value.position = CodablePoint(target); return .checkpoint(value)
        }
    }
}

private func rectangleEditorVertices(
    frame: CGRect,
    center: CGPoint? = nil,
    rotation: Double = 0
) -> [CGPoint] {
    rotatedRectangleCorners(
        frame: frame,
        center: center ?? CGPoint(x: frame.midX, y: frame.midY),
        rotation: rotation
    )
}

private func frameByMovingCorner(
    _ frame: CGRect,
    index: Int,
    to worldPoint: CGPoint,
    center: CGPoint? = nil,
    rotation: Double = 0
) -> CGRect? {
    guard (0..<4).contains(index),
          worldPoint.x.isFinite, worldPoint.y.isFinite,
          rotation.isFinite else { return nil }
    let originalCenter = center ?? CGPoint(x: frame.midX, y: frame.midY)
    let localPoint = rotateEditorPoint(
        worldPoint,
        around: originalCenter,
        rotation: -rotation
    )
    let localCorners = [
        CGPoint(x: frame.minX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.minY),
        CGPoint(x: frame.maxX, y: frame.maxY),
        CGPoint(x: frame.minX, y: frame.maxY)
    ]
    let fixed = localCorners[(index + 2) % 4]
    var target = localPoint
    switch index {
    case 0:
        target.x = min(target.x, fixed.x - 10)
        target.y = min(target.y, fixed.y - 10)
    case 1:
        target.x = max(target.x, fixed.x + 10)
        target.y = min(target.y, fixed.y - 10)
    case 2:
        target.x = max(target.x, fixed.x + 10)
        target.y = max(target.y, fixed.y + 10)
    case 3:
        target.x = min(target.x, fixed.x - 10)
        target.y = max(target.y, fixed.y + 10)
    default:
        return nil
    }

    let localCenter = CGPoint(x: (target.x + fixed.x) / 2, y: (target.y + fixed.y) / 2)
    let worldCenter = rotateEditorPoint(
        localCenter,
        around: originalCenter,
        rotation: rotation
    )
    let width = abs(target.x - fixed.x)
    let height = abs(target.y - fixed.y)
    return CGRect(
        x: worldCenter.x - width / 2,
        y: worldCenter.y - height / 2,
        width: width,
        height: height
    )
}

private func rotateEditorPoint(
    _ point: CGPoint,
    around center: CGPoint,
    rotation: Double
) -> CGPoint {
    let angle = CGFloat(rotation)
    let cosine = cos(angle)
    let sine = sin(angle)
    let dx = point.x - center.x
    let dy = point.y - center.y
    return CGPoint(
        x: center.x + dx * cosine - dy * sine,
        y: center.y + dx * sine + dy * cosine
    )
}

private extension MapGeometryShape {
    func editorOffset(dx: CGFloat, dy: CGFloat) -> MapGeometryShape {
        switch self {
        case let .rectangle(rect): .rectangle(CodableRect(rect.cgRect.offsetBy(dx: dx, dy: dy)))
        case let .polygon(points): .polygon(points.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) })
        case let .edgeChain(points): .edgeChain(points.map { CodablePoint(x: $0.x + dx, y: $0.y + dy) })
        }
    }
}
#endif
