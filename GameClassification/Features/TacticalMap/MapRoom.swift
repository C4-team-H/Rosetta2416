import CoreGraphics

struct MapRoom: Identifiable, Equatable {
    let id: String
    let name: String
    let worldFrame: CGRect

    init(name: String, worldFrame: CGRect) {
        self.id = name
        self.name = name
        self.worldFrame = worldFrame
    }
}
