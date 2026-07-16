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
            includeDoors: includeDoors
        )
    }

    static func make(
        story: StoryProgressionSystem,
        configuration: MapGeometryConfiguration,
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
            markers.append(MapMarker(
                id: station.id,
                kind: .station,
                status: markerStatus,
                worldPosition: station.position.cgPoint,
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
            guard let room = configuration.rooms.first(where: { $0.roomID == roomID }) else { continue }
            markers.append(MapMarker(
                id: "room-\(roomID.rawValue)",
                kind: kind,
                status: story.canAccess(roomID) ? .unlocked : .locked,
                worldPosition: CGPoint(x: room.triggerFrame.cgRect.midX, y: room.triggerFrame.cgRect.midY),
                title: room.name
            ))
        }

        markers.append(MapMarker(
            id: "kitchen",
            kind: .kitchen,
            status: .unlocked,
            worldPosition: configuration.stations.first(where: { $0.kind == .food && $0.isEnabled })?.position.cgPoint ?? .zero,
            title: "Kitchen Energy Station"
        ))

        if includeDoors {
            markers += configuration.doorways.compactMap { door -> MapMarker? in
                guard door.isEnabled, let doorID = door.doorID, let roomID = door.roomID else { return nil }
                return MapMarker(
                    id: doorID.nodeName,
                    kind: .door,
                    status: story.canAccess(roomID) ? .unlocked : .locked,
                    worldPosition: CGPoint(x: door.frame.cgRect.midX, y: door.frame.cgRect.midY),
                    title: doorID.displayName
                )
            }
        }
        return markers
    }
}
