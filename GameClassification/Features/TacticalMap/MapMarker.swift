import Foundation
import CoreGraphics

struct MapMarker: Identifiable, Equatable {
    let id: String
    let kind: MapMarkerKind
    let status: MapMarkerStatus
    let worldPosition: CGPoint
    let title: String?
    let isVisible: Bool

    init(
        id: String,
        kind: MapMarkerKind,
        status: MapMarkerStatus,
        worldPosition: CGPoint,
        title: String? = nil,
        isVisible: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.worldPosition = worldPosition
        self.title = title
        self.isVisible = isVisible
    }
}

@MainActor
enum TacticalMapMarkerFactory {
    static func make(
        story: StoryProgressionSystem,
        includeDoors: Bool = true
    ) -> [MapMarker] {
        make(
            story: story,
            configuration: .drawingSpaceDefault,
            visibilitySystem: nil,
            includeDoors: includeDoors
        )
    }

    static func make(
        story: StoryProgressionSystem,
        configuration: MapGeometryConfiguration,
        visibilitySystem: StationVisibilitySystem? = nil,
        includeDoors: Bool = true
    ) -> [MapMarker] {
        var markers: [MapMarker] = []

        for station in configuration.stations where station.kind == .mission && station.isEnabled {
            guard let objectiveID = station.interactionID,
                  let objective = story.objectives.first(where: { $0.id == objectiveID }) else { continue }
            let markerStatus: MapMarkerStatus
            switch objective.status {
            case .completed: markerStatus = .completed
            case .active, .available: markerStatus = .active
            case .blocked: markerStatus = .blocked
            case .locked: continue
            }
            let isVisible = visibilitySystem?.shouldShowOnMap(interactionID: objectiveID) ?? true
            markers.append(MapMarker(
                id: station.id,
                kind: .station,
                status: markerStatus,
                worldPosition: station.position.cgPoint,
                title: objective.definition.title,
                isVisible: isVisible
            ))
        }

        let roomKinds: [(RoomID, MapMarkerKind)] = [
            (.laboratory, .room(.laboratory)),
            (.engine, .room(.engine)),
            (.storage, .storage),
            (.cockpit, .cockpit)
        ]
        for (roomID, kind) in roomKinds {
            guard let room = configuration.rooms.first(where: { $0.roomID == roomID }) else { continue }
            let isTravelDestination = story.state.activeMission?.activeChallengeID == nil
                && story.state.activeMission?.targetRoomID == roomID
            markers.append(MapMarker(
                id: "room-\(roomID.rawValue)",
                kind: kind,
                status: story.canAccess(roomID) ? .unlocked : .locked,
                worldPosition: CGPoint(x: room.roomTriggerBounds.midX, y: room.roomTriggerBounds.midY),
                title: room.name,
                isVisible: visibilitySystem == nil || isTravelDestination
            ))
        }

        let kitchenVisible = visibilitySystem?.shouldShowStation(interactionID: StationVisibilitySystem.kitchenInteractionID) ?? true
        markers.append(MapMarker(
            id: "kitchen",
            kind: .kitchen,
            status: .unlocked,
            worldPosition: configuration.stations.first(where: { $0.kind == .food && $0.isEnabled })?.position.cgPoint ?? .zero,
            title: "Kitchen Energy Station",
            isVisible: kitchenVisible
        ))

        if includeDoors && story.state.engineProgress >= 10 {
            markers += configuration.doorways.compactMap { door -> MapMarker? in
                guard door.isEnabled, let doorID = door.doorID, let roomID = door.roomID else { return nil }
                return MapMarker(
                    id: doorID.nodeName,
                    kind: .door,
                    status: story.canAccess(roomID) ? .unlocked : .locked,
                    worldPosition: CGPoint(x: door.doorwayBounds.midX, y: door.doorwayBounds.midY),
                    title: doorID.displayName
                )
            }
        }

        if visibilitySystem?.shouldShowOnMap(interactionID: StationVisibilitySystem.albumInteractionID)
            ?? story.state.albumBook.isMarkerVisible {
            markers.append(MapMarker(
                id: "album-book",
                kind: .albumBook,
                status: .unlocked,
                worldPosition: configuration.albumBookPosition,
                title: "Reference Album"
            ))
        }

        return markers
    }
}
