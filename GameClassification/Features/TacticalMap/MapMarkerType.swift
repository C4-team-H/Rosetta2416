enum MapMarkerKind: Equatable {
    case objective
    case station
    case room(RoomID)
    case kitchen
    case storage
    case cockpit
    case door
    case checkpoint
    case albumBook
}

enum MapMarkerStatus: Equatable {
    case active
    case completed
    case locked
    case unlocked
    case blocked
}
