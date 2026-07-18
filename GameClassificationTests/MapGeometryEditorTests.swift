import CoreGraphics
import SpriteKit
import Testing
import UIKit
@testable import GameClassification

@Suite("Map geometry configuration and editor")
@MainActor
struct MapGeometryEditorTests {
    @Test("Canonical geometry is direct 5504 by 4128 world data and round-trips through Codable")
    func canonicalConfigurationRoundTrip() throws {
        let configuration = MapGeometryConfiguration.drawingSpaceDefault
        #expect(configuration.worldSize == CodableSize(width: 5_504, height: 4_128))
        #expect(configuration.rooms.count == RoomID.allCases.count)
        #expect(configuration.doorways.count == DoorID.allCases.count)
        #expect(configuration.rooms.first(where: { $0.roomID == .cockpit })?.frame.x == 2_180)

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(MapGeometryConfiguration.self, from: data)
        #expect(decoded == configuration)

        let footprintJSON = """
        {"centerOffset":{"x":0,"y":-22.93},"width":92,"height":46,"obstacleRadius":111}
        """
        let footprint = try JSONDecoder().decode(
            MapPlayerFootprintDefinition.self,
            from: Data(footprintJSON.utf8)
        )
        #expect(footprint.width == 92)
        #expect(footprint.height == 46)
        #expect(footprint.obstacleRadius == 111)

        let legacyFootprintJSON = """
        {"centerOffset":{"x":0,"y":-20},"radius":45}
        """
        let legacyFootprint = try JSONDecoder().decode(
            MapPlayerFootprintDefinition.self,
            from: Data(legacyFootprintJSON.utf8)
        )
        #expect(legacyFootprint.width == 90)
        #expect(legacyFootprint.height == 90)
        #expect(legacyFootprint.obstacleRadius == 45)

        let legacyStationJSON = """
        {"id":"legacy-station","name":"Legacy Station","kind":"mission","position":{"x":100,"y":200},"isEnabled":true,"isRequired":false}
        """
        let legacyStation = try JSONDecoder().decode(
            MapStationDefinition.self,
            from: Data(legacyStationJSON.utf8)
        )
        #expect(legacyStation.vertices == nil)
        #expect(legacyStation.stationPoints.count == 4)
    }

    @Test("Store coalesces a drag transaction into one undo entry")
    func storeHistoryAndRestrictions() {
        let store = MapGeometryStore()
        let wallID = MapElementID(category: .wall, rawValue: store.configuration.walls[0].id)
        let original = store.configuration.walls[0]

        store.beginTransaction()
        var firstMove = original
        firstMove.frame.x += 10
        store.update(.wall(firstMove), validate: false)
        var secondMove = firstMove
        secondMove.frame.x += 20
        store.update(.wall(secondMove), validate: false)
        store.endTransaction(validate: false)

        #expect(store.configuration.walls[0].frame.x == original.frame.x + 30)
        #expect(store.canUndo)
        store.undo()
        #expect(store.configuration.walls[0] == original)
        #expect(store.canRedo)
        store.redo()
        #expect(store.configuration.walls[0].frame.x == original.frame.x + 30)

        let requiredRoom = store.configuration.rooms.first(where: { $0.isRequired })!
        #expect(!store.remove(MapElementID(category: .room, rawValue: requiredRoom.id)))
        #expect(store.duplicate(MapElementID(category: .room, rawValue: requiredRoom.id)) == nil)

        let copyID = store.duplicate(wallID)
        #expect(copyID?.rawValue == "\(wallID.rawValue)-copy-1")
        #expect(copyID.flatMap { store.configuration.element(id: $0) } != nil)
    }

    @Test("Resize enforces snapping and the ten point minimum")
    func resizeMinimumAndSnapping() {
        let store = MapGeometryStore()
        let wall = store.configuration.walls[0]
        store.selectedElement = .wall(wall.id)
        store.resizeSelected(
            to: CGRect(x: 13, y: 18, width: 1, height: 2),
            grid: MapEditorGridConfiguration(gridSize: 10, snapToGrid: true)
        )
        let resized = store.configuration.walls.first(where: { $0.id == wall.id })!.frame.cgRect
        #expect(resized.origin == CGPoint(x: 10, y: 20))
        #expect(resized.size == CGSize(width: 10, height: 10))
    }

    @Test("Validator catches global duplicate IDs and unbound mission stations")
    func validatorDiagnostics() {
        var configuration = MapGeometryConfiguration.drawingSpaceDefault
        let duplicateID = configuration.rooms[0].id
        configuration.walls.append(MapWallDefinition(
            id: duplicateID,
            name: "Duplicate",
            frame: CodableRect(x: 100, y: 100, width: 20, height: 20),
            isEnabled: true,
            isRequired: false
        ))
        configuration.stations.append(MapStationDefinition(
            id: "station-unbound-test",
            name: "Unbound",
            kind: .mission,
            roomID: nil,
            position: CodablePoint(x: 1_000, y: 1_000),
            interactionID: nil,
            isEnabled: true,
            isRequired: false
        ))

        let validator = MapGeometryValidator()
        #expect(validator.structuralIssues(in: configuration).contains { $0.message.contains("Duplicate map ID") })

        configuration.walls.removeLast()
        let result = validator.validate(configuration, includeReachability: false)
        #expect(result.warnings.contains { $0.message.contains("not bound") })
    }

    @Test("Bundled geometry passes complete topology and story-gate validation")
    func bundledGeometryValidation() {
        let result = MapGeometryValidator().validate(.drawingSpaceDefault)
        #expect(result.errors.isEmpty, "\(result.errors.map(\.message))")
    }

    @Test("Runtime compiler publishes the same revision and edited coordinates")
    func runtimeCompilerRevision() {
        var configuration = MapGeometryConfiguration.drawingSpaceDefault
        configuration.walls[0].frame.x += 25
        configuration.stations[0].position.x += 40
        let map = GameMapLayout.makeRuntimeMap(from: configuration, revision: 42)

        #expect(map.revision == 42)
        #expect(map.colliders.first(where: { $0.id == configuration.walls[0].id })?.shape.bounds == configuration.walls[0].rotatedBounds)
        #expect(map.stations.first(where: { $0.id == configuration.stations[0].interactionID })?.worldPosition == configuration.stations[0].position.cgPoint)
    }

    @Test("Rotated walls update editor state, polygon collision, and old draft decoding")
    func rotatedWallCompilation() throws {
        let legacyWallJSON = """
        {"id":"legacy-wall","name":"Legacy","frame":{"x":10,"y":20,"width":200,"height":30},"isEnabled":true,"isRequired":false}
        """
        let legacyWall = try JSONDecoder().decode(
            MapWallDefinition.self,
            from: Data(legacyWallJSON.utf8)
        )
        #expect(legacyWall.rotation == nil)

        let store = MapGeometryStore()
        let wall = store.configuration.walls[0]
        store.selectedElement = .wall(wall.id)
        store.updateSelectedRotation(.pi / 4)
        let rotatedWall = store.configuration.walls.first(where: { $0.id == wall.id })!
        #expect(abs((rotatedWall.rotation ?? 0) - .pi / 4) < 0.000_1)

        let map = GameMapLayout.makeRuntimeMap(from: store.configuration, revision: 7)
        let collider = try #require(map.colliders.first(where: { $0.id == wall.id }))
        guard case let .polygon(points) = collider.shape else {
            Issue.record("A rotated wall must compile to a polygon")
            return
        }
        #expect(points.count == 4)
        #expect(collider.shape.bounds != rotatedWall.frame.cgRect)

        let shipNode = ShipMapNode(map: map, debugEnabled: false)
        let wallNode = try #require(shipNode.node(for: MapElementID(category: .wall, rawValue: wall.id)))
        #expect(wallNode.physicsBody != nil)

        let exported = MapGeometryExporter.swiftCode(for: store.configuration)
        #expect(exported.contains("rotation: 0.79"))
    }

    @Test("Wall endpoint nodes can be selected and moved without changing thickness")
    func wallEndpointEditing() {
        let wall = MapWallDefinition(
            id: "wall-node-test",
            name: "Node Test",
            frame: CodableRect(x: 100, y: 100, width: 200, height: 20),
            rotation: 0,
            isEnabled: true,
            isRequired: false
        )
        let originalEndpoints = wall.centerlineEndpoints
        #expect(originalEndpoints == [CGPoint(x: 100, y: 110), CGPoint(x: 300, y: 110)])

        let target = CGPoint(x: 80, y: 260)
        let edited = wall.updatingEndpoint(at: 0, to: target)
        let editedEndpoints = edited.centerlineEndpoints
        #expect(hypot(editedEndpoints[0].x - target.x, editedEndpoints[0].y - target.y) < 0.001)
        #expect(hypot(
            editedEndpoints[1].x - originalEndpoints[1].x,
            editedEndpoints[1].y - originalEndpoints[1].y
        ) < 0.001)
        #expect(abs(min(edited.frame.width, edited.frame.height) - 20) < 0.001)
        #expect(abs(edited.rotationRadians) > 0.000_1)

        var configuration = MapGeometryConfiguration.drawingSpaceDefault
        configuration.walls.append(edited)
        let runtime = GameMapLayout.makeRuntimeMap(from: configuration)
        guard let collider = runtime.colliders.first(where: { $0.id == edited.id }),
              case .polygon = collider.shape else {
            Issue.record("A node-edited wall must produce rotated polygon collision")
            return
        }
    }

    #if DEBUG
    @Test("Node mode adds, moves, and deletes points for every editable map geometry category")
    func allGeometryNodeDragging() throws {
        let defaultsName = "MapGeometryEditorTests.Nodes.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let store = MapGeometryStore()
        let settings = GameDebugSettings(defaults: defaults)
        settings.isMapDebugEnabled = true
        settings.editorMode = .editNodes
        settings.snapToGrid = false

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let scene = SKScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        let camera = SKCameraNode()
        camera.setScale(3.5)
        scene.addChild(camera)
        scene.camera = camera
        view.presentScene(scene)

        let converter = MapEditorCoordinateConverter()
        converter.attach(view: view, scene: scene, camera: camera)
        let session = GameSessionState(localPlayer: PlayerState(
            id: "node-drag-test",
            name: "Tester",
            worldPosition: .zero,
            isConnected: true
        ))
        let viewModel = MapDebugViewModel(
            store: store,
            settings: settings,
            converter: converter,
            repository: nil,
            sessionState: session
        )

        func dragFirstNode(of id: MapElementID, by offset: CGVector) throws {
            store.selectedElement = MapEditorSelection(id)
            let original = try #require(store.configuration.element(id: id))
            camera.position = original.worldPosition
            let startScreen = try #require(viewModel.vertexScreenPoints(for: original).first)
            let startWorld = try #require(converter.screenToWorld(startScreen))
            let targetWorld = CGPoint(x: startWorld.x + offset.dx, y: startWorld.y + offset.dy)
            let targetScreen = try #require(converter.worldToScreen(targetWorld))

            viewModel.beginDrag(screenPoint: startScreen)
            #expect(viewModel.activeVertexIndex == 0)
            viewModel.updateDrag(screenPoint: targetScreen)
            viewModel.endDrag(screenPoint: targetScreen)
        }

        func addNodeOnFirstEdge(of id: MapElementID) throws {
            settings.editorMode = .addNode
            store.selectedElement = MapEditorSelection(id)
            let original = try #require(store.configuration.element(id: id))
            camera.position = original.worldPosition
            let points = viewModel.vertexScreenPoints(for: original)
            #expect(points.count >= 3)
            let edgeMidpoint = CGPoint(
                x: (points[0].x + points[1].x) / 2,
                y: (points[0].y + points[1].y) / 2
            )

            viewModel.tap(screenPoint: edgeMidpoint)

            let edited = try #require(store.configuration.element(id: id))
            #expect(viewModel.vertexScreenPoints(for: edited).count == points.count + 1)
            #expect(viewModel.selectedVertexIndex == 1)
        }

        func deleteNode(of id: MapElementID, at index: Int) throws {
            settings.editorMode = .deleteNode
            store.selectedElement = MapEditorSelection(id)
            let original = try #require(store.configuration.element(id: id))
            camera.position = original.worldPosition
            let points = viewModel.vertexScreenPoints(for: original)
            let node = try #require(points.indices.contains(index) ? points[index] : nil)

            viewModel.tap(screenPoint: node)

            let edited = try #require(store.configuration.element(id: id))
            let expectedCount = points.count > 3 ? points.count - 1 : points.count
            #expect(viewModel.vertexScreenPoints(for: edited).count == expectedCount)
            if points.count > 3 {
                #expect(viewModel.selectedVertexIndex == nil)
            } else {
                #expect(viewModel.selectedVertexIndex == index)
                #expect(store.statusMessage?.contains("at least three nodes") == true)
            }
        }

        let room = store.configuration.rooms[0]
        let originalRoomFrame = room.frame.cgRect
        let originalTriggerFrame = room.triggerFrame.cgRect
        let originalRoomPoints = room.walkablePoints
        let originalTriggerPoints = room.roomTriggerPoints
        try dragFirstNode(
            of: MapElementID(category: .room, rawValue: room.id),
            by: CGVector(dx: -40, dy: -30)
        )
        let editedRoom = try #require(store.configuration.rooms.first(where: { $0.id == room.id }))
        #expect(editedRoom.frame.cgRect.minX < originalRoomFrame.minX)
        #expect(editedRoom.frame.cgRect.minY < originalRoomFrame.minY)
        #expect(editedRoom.frame.cgRect.maxX == originalRoomFrame.maxX)
        #expect(editedRoom.frame.cgRect.maxY == originalRoomFrame.maxY)
        #expect(editedRoom.triggerFrame.cgRect != originalTriggerFrame)
        #expect(editedRoom.vertices != nil)
        #expect(Array(editedRoom.walkablePoints.dropFirst()) == Array(originalRoomPoints.dropFirst()))
        #expect(Array(editedRoom.roomTriggerPoints.dropFirst()) == Array(originalTriggerPoints.dropFirst()))

        let corridor = store.configuration.corridors[0]
        let originalCorridorFrame = corridor.frame.cgRect
        let originalCorridorPoints = corridor.walkablePoints
        try dragFirstNode(
            of: MapElementID(category: .corridor, rawValue: corridor.id),
            by: CGVector(dx: -35, dy: -25)
        )
        let editedCorridor = try #require(store.configuration.corridors.first(where: { $0.id == corridor.id }))
        #expect(editedCorridor.frame.cgRect != originalCorridorFrame)
        #expect(editedCorridor.frame.cgRect.maxX == originalCorridorFrame.maxX)
        #expect(editedCorridor.frame.cgRect.maxY == originalCorridorFrame.maxY)
        #expect(editedCorridor.vertices != nil)
        #expect(Array(editedCorridor.walkablePoints.dropFirst()) == Array(originalCorridorPoints.dropFirst()))

        let wall = store.configuration.walls[0]
        let originalWallPoints = wall.rotatedCorners
        try dragFirstNode(
            of: MapElementID(category: .wall, rawValue: wall.id),
            by: CGVector(dx: -30, dy: 45)
        )
        let editedWall = try #require(store.configuration.walls.first(where: { $0.id == wall.id }))
        #expect(editedWall.vertices != nil)
        #expect(editedWall.rotatedCorners[0] != originalWallPoints[0])
        #expect(Array(editedWall.rotatedCorners.dropFirst()) == Array(originalWallPoints.dropFirst()))

        let doorway = store.configuration.doorways[0]
        let originalDoorwayFrame = doorway.frame.cgRect
        let originalDoorwayPoints = doorway.doorwayPoints
        try dragFirstNode(
            of: MapElementID(category: .doorway, rawValue: doorway.id),
            by: CGVector(dx: -25, dy: -25)
        )
        let editedDoorway = try #require(store.configuration.doorways.first(where: { $0.id == doorway.id }))
        #expect(editedDoorway.frame.cgRect != originalDoorwayFrame)
        #expect(editedDoorway.frame.cgRect.maxX == originalDoorwayFrame.maxX)
        #expect(editedDoorway.frame.cgRect.maxY == originalDoorwayFrame.maxY)
        #expect(editedDoorway.vertices != nil)
        #expect(Array(editedDoorway.doorwayPoints.dropFirst()) == Array(originalDoorwayPoints.dropFirst()))

        let blockedRectangle = MapBlockedAreaDefinition(
            id: "blocked-node-test",
            name: "Blocked Node Test",
            shape: .rectangle(CodableRect(x: 1_000, y: 1_000, width: 180, height: 120)),
            isEnabled: true,
            isRequired: false
        )
        store.insert(.blockedArea(blockedRectangle))
        guard case let .rectangle(originalBlockedRect) = blockedRectangle.shape else {
            Issue.record("Expected a rectangular blocked area")
            return
        }
        let originalBlockedFrame = originalBlockedRect.cgRect
        try dragFirstNode(
            of: MapElementID(category: .blockedArea, rawValue: blockedRectangle.id),
            by: CGVector(dx: -20, dy: -20)
        )
        let editedBlocked = try #require(store.configuration.blockedAreas.first(where: { $0.id == blockedRectangle.id }))
        guard case let .rectangle(editedBlockedRect) = editedBlocked.shape else {
            Issue.record("Node editing must preserve a blocked rectangle's shape type")
            return
        }
        let editedBlockedFrame = editedBlockedRect.cgRect
        #expect(editedBlockedFrame != originalBlockedFrame)
        #expect(editedBlockedFrame.maxX == originalBlockedFrame.maxX)
        #expect(editedBlockedFrame.maxY == originalBlockedFrame.maxY)
        let blockedID = MapElementID(category: .blockedArea, rawValue: blockedRectangle.id)

        let blockedEdgeChain = MapBlockedAreaDefinition(
            id: "blocked-edge-chain-node-test",
            name: "Blocked Edge Chain Node Test",
            shape: .edgeChain([
                CodablePoint(x: 1_300, y: 1_000),
                CodablePoint(x: 1_420, y: 1_000),
                CodablePoint(x: 1_420, y: 1_120),
                CodablePoint(x: 1_540, y: 1_120)
            ]),
            isEnabled: true,
            isRequired: false
        )
        store.insert(.blockedArea(blockedEdgeChain))
        let blockedEdgeChainID = MapElementID(
            category: .blockedArea,
            rawValue: blockedEdgeChain.id
        )

        var object = store.configuration.objects[0]
        object.rotation = .pi / 4
        store.update(.object(object), validate: false)
        let originalObjectPoints = object.objectPoints
        try dragFirstNode(
            of: MapElementID(category: .object, rawValue: object.id),
            by: CGVector(dx: -45, dy: -20)
        )
        let editedObject = try #require(store.configuration.objects.first(where: { $0.id == object.id }))
        #expect(editedObject.objectPoints[0] != originalObjectPoints[0])
        #expect(editedObject.size.isValid)
        #expect(abs(editedObject.rotation - object.rotation) < 0.000_1)
        #expect(editedObject.vertices != nil)
        #expect(Array(editedObject.objectPoints.dropFirst()) == Array(originalObjectPoints.dropFirst()))

        let missionStation = try #require(store.configuration.stations.first(where: { $0.kind == .mission }))
        let missionStationID = MapElementID(category: .missionStation, rawValue: missionStation.id)
        let originalStationPosition = missionStation.position
        try dragFirstNode(of: missionStationID, by: CGVector(dx: -30, dy: -20))
        let editedMissionStation = try #require(store.configuration.stations.first(where: { $0.id == missionStation.id }))
        #expect(editedMissionStation.vertices?.count == 4)
        #expect(editedMissionStation.position != originalStationPosition)

        let foodStation = try #require(store.configuration.stations.first(where: { $0.kind == .food }))
        let foodStationID = MapElementID(category: .foodStation, rawValue: foodStation.id)

        let roomTriggerCountBeforeInsertion = editedRoom.roomTriggerPoints.count
        try addNodeOnFirstEdge(of: MapElementID(category: .room, rawValue: room.id))
        try addNodeOnFirstEdge(of: MapElementID(category: .corridor, rawValue: corridor.id))
        try addNodeOnFirstEdge(of: MapElementID(category: .wall, rawValue: wall.id))
        try addNodeOnFirstEdge(of: MapElementID(category: .doorway, rawValue: doorway.id))
        try addNodeOnFirstEdge(of: blockedID)
        try addNodeOnFirstEdge(of: blockedEdgeChainID)
        try addNodeOnFirstEdge(of: MapElementID(category: .object, rawValue: object.id))
        try addNodeOnFirstEdge(of: missionStationID)
        try addNodeOnFirstEdge(of: foodStationID)
        let roomAfterInsertion = try #require(store.configuration.rooms.first(where: { $0.id == room.id }))
        #expect(roomAfterInsertion.roomTriggerPoints.count == roomTriggerCountBeforeInsertion + 1)
        let blockedAfterInsertion = try #require(
            store.configuration.blockedAreas.first(where: { $0.id == blockedRectangle.id })
        )
        guard case let .polygon(blockedPolygonPoints) = blockedAfterInsertion.shape else {
            Issue.record("Adding a node to a blocked rectangle must convert it to a polygon")
            return
        }
        #expect(blockedPolygonPoints.count == 5)
        let edgeChainAfterInsertion = try #require(
            store.configuration.blockedAreas.first(where: { $0.id == blockedEdgeChain.id })
        )
        guard case let .edgeChain(edgeChainPoints) = edgeChainAfterInsertion.shape else {
            Issue.record("Adding a node must preserve blocked edge-chain topology")
            return
        }
        #expect(edgeChainPoints.count == 5)

        try deleteNode(of: MapElementID(category: .room, rawValue: room.id), at: 1)
        try deleteNode(of: MapElementID(category: .corridor, rawValue: corridor.id), at: 1)
        try deleteNode(of: MapElementID(category: .wall, rawValue: wall.id), at: 1)
        try deleteNode(of: MapElementID(category: .doorway, rawValue: doorway.id), at: 1)
        try deleteNode(of: blockedID, at: 1)
        try deleteNode(of: blockedEdgeChainID, at: 1)
        try deleteNode(of: MapElementID(category: .object, rawValue: object.id), at: 1)
        try deleteNode(of: missionStationID, at: 1)
        try deleteNode(of: foodStationID, at: 1)
        let roomAfterDeletion = try #require(store.configuration.rooms.first(where: { $0.id == room.id }))
        #expect(roomAfterDeletion.roomTriggerPoints.count == roomTriggerCountBeforeInsertion)
        let blockedAfterDeletion = try #require(
            store.configuration.blockedAreas.first(where: { $0.id == blockedRectangle.id })
        )
        guard case let .polygon(blockedPointsAfterDeletion) = blockedAfterDeletion.shape else {
            Issue.record("Deleting a node must preserve the blocked polygon")
            return
        }
        #expect(blockedPointsAfterDeletion.count == 4)
        let edgeChainAfterDeletion = try #require(
            store.configuration.blockedAreas.first(where: { $0.id == blockedEdgeChain.id })
        )
        guard case let .edgeChain(edgeChainPointsAfterDeletion) = edgeChainAfterDeletion.shape else {
            Issue.record("Deleting a node must preserve the blocked edge-chain topology")
            return
        }
        #expect(edgeChainPointsAfterDeletion.count == 4)

        let runtime = GameMapLayout.makeRuntimeMap(from: store.configuration, revision: 99)
        guard case .polygon = try #require(runtime.rooms.first(where: { $0.sourceID == room.id })?.walkableShape) else {
            Issue.record("A freeform room must compile into polygon walkability")
            return
        }
        guard case .polygon = try #require(runtime.corridors.first(where: { $0.id == corridor.id })?.shape) else {
            Issue.record("A freeform corridor must compile into polygon walkability")
            return
        }
        guard case .polygon = try #require(runtime.colliders.first(where: { $0.id == wall.id })?.shape) else {
            Issue.record("A freeform wall must compile into polygon collision")
            return
        }
        guard case .polygon = try #require(runtime.doorways.first(where: { $0.sourceID == doorway.id })?.shape) else {
            Issue.record("A freeform doorway must compile into polygon walkability and physics")
            return
        }
        guard case .polygon = try #require(runtime.colliders.first(where: { $0.id == object.id })?.shape) else {
            Issue.record("A freeform object must compile into polygon collision")
            return
        }

        func elementCount(for category: MapElementCategory) -> Int {
            store.configuration.allElements.filter { $0.id.category == category }.count
        }
        settings.editorMode = .create
        camera.position = CGPoint(x: 2_000, y: 1_600)
        for (index, category) in MapElementCategory.debugShapeCreationCases.enumerated() {
            let countBefore = elementCount(for: category)
            viewModel.selectedCreationCategory = category
            let startWorld = CGPoint(x: 1_400 + CGFloat(index) * 220, y: 1_300)
            let endWorld = CGPoint(x: startWorld.x + 120, y: startWorld.y + 90)
            let startScreen = try #require(converter.worldToScreen(startWorld))
            let endScreen = try #require(converter.worldToScreen(endWorld))
            viewModel.beginDrag(screenPoint: startScreen)
            viewModel.updateDrag(screenPoint: endScreen)
            viewModel.endDrag(screenPoint: endScreen)
            #expect(elementCount(for: category) == countBefore + 1)
            #expect(store.selectedElement?.elementID.category == category)
        }

        let createdStationID = try #require(store.selectedElement?.elementID)
        #expect(createdStationID.category == .foodStation)
        try deleteNode(of: createdStationID, at: 0)
        try deleteNode(of: createdStationID, at: 0)
    }
    #endif

    @Test("Pending edits are merged and only the affected SpriteKit layer is rebuilt")
    func coalescedIncrementalNodeUpdate() {
        let store = MapGeometryStore()
        _ = store.consumePendingChangeSet()
        var configuration = store.configuration
        var wall = configuration.walls[0]
        var corridor = configuration.corridors[0]
        wall.frame.x += 15
        corridor.frame.y += 20
        store.update(.wall(wall), validate: false)
        store.update(.corridor(corridor), validate: false)
        let changes = store.consumePendingChangeSet()
        #expect(changes.updated.contains(MapElementID(category: .wall, rawValue: wall.id)))
        #expect(changes.updated.contains(MapElementID(category: .corridor, rawValue: corridor.id)))

        let originalMap = GameMapLayout.makeRuntimeMap(from: configuration)
        let node = ShipMapNode(map: originalMap, debugEnabled: false)
        let wallID = MapElementID(category: .wall, rawValue: wall.id)
        let roomID = MapElementID(category: .room, rawValue: configuration.rooms[0].id)
        let oldWallNode = node.node(for: wallID)
        let oldRoomNode = node.node(for: roomID)

        configuration.walls[0] = wall
        configuration.corridors[0] = corridor
        node.apply(
            map: GameMapLayout.makeRuntimeMap(from: configuration, revision: 1),
            changeSet: changes
        )
        #expect(node.node(for: wallID) !== oldWallNode)
        #expect(node.node(for: roomID) === oldRoomNode)
        #expect(node.node(for: wallID)?.position.x == wall.frame.cgRect.midX)
    }

    @Test("Door geometry rebuild preserves authoritative runtime state and masks")
    func doorRebuildPreservesState() {
        let originalMap = GameMapLayout.makeRuntimeMap(from: .drawingSpaceDefault)
        let node = ShipMapNode(map: originalMap, debugEnabled: false)
        let engineDoor = node.doorNodes[.engine]!
        engineDoor.lock()

        var edited = MapGeometryConfiguration.drawingSpaceDefault
        let index = edited.doorways.firstIndex(where: { $0.doorID == .engine })!
        edited.doorways[index].frame.x += 30
        node.apply(map: GameMapLayout.makeRuntimeMap(from: edited, revision: 1))

        let rebuilt = node.doorNodes[.engine]!
        #expect(rebuilt.state == .locked)
        #expect(rebuilt.physicsBody?.categoryBitMask == PhysicsCategory.closedDoor)
        #expect(rebuilt.position.x == edited.doorways[index].frame.cgRect.midX)
    }

    @Test("Tactical map consumes live geometry from the shared store")
    func tacticalMapUsesSharedRevision() {
        let store = MapGeometryStore()
        let session = GameSessionState(localPlayer: PlayerState(
            id: "map-editor-test",
            name: "Tester",
            worldPosition: store.configuration.spawnPoint(for: .sleepingRoom)!,
            isConnected: true
        ))
        let viewModel = TacticalMapViewModel(sessionState: session, geometryStore: store)
        let food = store.configuration.stations.first(where: { $0.kind == .food })!
        var movedFood = food
        movedFood.position.x += 75
        store.update(.station(movedFood), validate: false)

        #expect(viewModel.geometryStore === store)
        #expect(viewModel.visibleMarkers.first(where: { $0.id == "kitchen" })?.worldPosition == movedFood.position.cgPoint)
    }

    @Test("SpriteKit and editor screen conversion round-trips across camera transforms")
    func coordinateConverterRoundTrip() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let scene = SKScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        let camera = SKCameraNode()
        camera.position = CGPoint(x: 2_000, y: 1_500)
        camera.setScale(0.75)
        scene.addChild(camera)
        scene.camera = camera
        view.presentScene(scene)

        let converter = MapEditorCoordinateConverter()
        converter.attach(view: view, scene: scene, camera: camera)
        let worldPoint = CGPoint(x: 2_125, y: 1_620)
        let screenPoint = try #require(converter.worldToScreen(worldPoint))
        let roundTrip = try #require(converter.screenToWorld(screenPoint))
        #expect(hypot(roundTrip.x - worldPoint.x, roundTrip.y - worldPoint.y) < 0.01)

        let initialCameraPosition = camera.position
        #expect(converter.panCamera(
            screenTranslation: CGSize(width: -40, height: -25),
            worldSize: CGSize(width: 5_504, height: 4_128)
        ))
        #expect(camera.position.x > initialCameraPosition.x)
        #expect(camera.position.y < initialCameraPosition.y)

        let afterNegativePan = camera.position
        #expect(converter.panCamera(
            screenTranslation: CGSize(width: 40, height: 25),
            worldSize: CGSize(width: 5_504, height: 4_128)
        ))
        #expect(camera.position.x < afterNegativePan.x)
        #expect(camera.position.y > afterNegativePan.y)

        #expect(!converter.panCamera(
            screenTranslation: .zero,
            worldSize: CGSize(width: 5_504, height: 4_128)
        ))
        converter.zoomCamera(multiplier: 1.2, worldSize: CGSize(width: 5_504, height: 4_128))
        let transformedScreen = try #require(converter.worldToScreen(camera.position))
        let transformedRoundTrip = try #require(converter.screenToWorld(transformedScreen))
        #expect(hypot(transformedRoundTrip.x - camera.position.x, transformedRoundTrip.y - camera.position.y) < 0.01)

        converter.setCameraZoomLevel(10, worldSize: CGSize(width: 5_504, height: 4_128))
        #expect(abs(camera.xScale - MapEditorCoordinateConverter.minimumCameraScale) < 0.001)
        #expect(abs(converter.cameraZoomLevel - 4) < 0.001)

        converter.setCameraZoomLevel(0.1, worldSize: CGSize(width: 5_504, height: 4_128))
        #expect(abs(camera.xScale - MapEditorCoordinateConverter.maximumCameraScale) < 0.001)
        #expect(abs(converter.cameraZoomLevel - (1 / 3.5)) < 0.001)
    }

    #if DEBUG
    @Test("Draft repository is atomic, rejects old schemas, and deletes cleanly")
    func draftRepositoryLifecycle() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MapGeometryEditorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try LocalMapGeometryRepository(directoryURL: directory)
        let configuration = MapGeometryConfiguration.drawingSpaceDefault

        try repository.save(configuration)
        #expect(try repository.load() == configuration)

        var incompatible = configuration
        incompatible.schemaVersion = 999
        try MapGeometryExporter.jsonData(for: incompatible).write(to: repository.fileURL, options: .atomic)
        #expect(throws: MapGeometryRepositoryError.self) { try repository.load() }

        try repository.deleteSavedConfiguration()
        #expect(try repository.load() == nil)
    }

    @Test("Exporter output is stable and ordered")
    func stableExporter() throws {
        var configuration = MapGeometryConfiguration.drawingSpaceDefault
        configuration.walls.reverse()
        let firstJSON = try MapGeometryExporter.jsonString(for: configuration)
        let secondJSON = try MapGeometryExporter.jsonString(for: configuration)
        let swift = MapGeometryExporter.swiftCode(for: configuration)

        #expect(firstJSON == secondJSON)
        #expect(firstJSON.hasSuffix("\n"))
        #expect(swift.contains("static var drawingSpaceDefault"))
        #expect(swift.contains("obstacleRadius:"))
        let sortedIDs = configuration.walls.map(\.id).sorted()
        #expect(swift.range(of: sortedIDs[0])!.lowerBound < swift.range(of: sortedIDs[1])!.lowerBound)
    }
    #endif
}
