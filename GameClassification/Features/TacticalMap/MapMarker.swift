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
    static func make(story: StoryProgressionSystem, includeDoors: Bool = true) -> [MapMarker] {
        var markers: [MapMarker] = []

        for station in GameMapLayout.stationDefinitions {
            guard let objective = story.objectives.first(where: { $0.id == station.id }) else { continue }
            let markerStatus: MapMarkerStatus
            switch objective.status {
            case .completed: markerStatus = .completed
            case .active, .available: markerStatus = .active
            case .blocked: markerStatus = .blocked
            case .locked: continue
            }
            markers.append(MapMarker(
                id: "station-\(station.id)",
                kind: .station,
                status: markerStatus,
                worldPosition: station.worldPosition,
                title: objective.definition.title
            ))
        }

        let roomKinds: [(RoomID, MapMarkerKind)] = [
            (.laboratory, .room(.laboratory)),
            (.engine, .room(.engine)),
            (.storage, .storage),
            (.cockpit, .cockpit)
        ]
        for (roomID, kind) in roomKinds {
            guard let room = GameMapLayout.rooms.first(where: { $0.id == roomID }) else { continue }
            markers.append(MapMarker(
                id: "room-\(roomID.rawValue)",
                kind: kind,
                status: story.canAccess(roomID) ? .unlocked : .locked,
                worldPosition: CGPoint(x: room.worldFrame.midX, y: room.worldFrame.midY),
                title: room.name
            ))
        }

        markers.append(MapMarker(
            id: "kitchen",
            kind: .kitchen,
            status: .unlocked,
            worldPosition: GameMapLayout.foodStationPosition,
            title: "Kitchen Energy Station"
        ))

        if includeDoors {
            markers += GameMapLayout.doorDefinitions.map { door in
                MapMarker(
                    id: door.id.nodeName,
                    kind: .door,
                    status: story.canAccess(door.roomID) ? .unlocked : .locked,
                    worldPosition: door.worldPosition,
                    title: door.id.displayName
                )
            }
        }
        return markers
    }
}
