import CoreGraphics

struct MapWallSegment: Identifiable, Equatable {
    let id: Int
    let start: CGPoint
    let end: CGPoint

    init(id: Int, start: CGPoint, end: CGPoint) {
        self.id = id
        self.start = start
        self.end = end
    }
}
