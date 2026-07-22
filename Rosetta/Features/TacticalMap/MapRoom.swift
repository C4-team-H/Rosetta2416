import CoreGraphics

struct MapRoom: Identifiable, Equatable {
    let id: RoomID
    let name: String
    let worldFrame: CGRect

    init(id: RoomID, name: String, worldFrame: CGRect) {
        self.id = id
        self.name = name
        self.worldFrame = worldFrame
    }
}
