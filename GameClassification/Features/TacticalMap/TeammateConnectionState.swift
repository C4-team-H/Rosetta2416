enum TeammateConnectionState: Equatable {
    case connected
    case reconnecting
    case disconnected

    var accessibilityDescription: String {
        switch self {
        case .connected:
            "connected"
        case .reconnecting:
            "reconnecting"
        case .disconnected:
            "disconnected"
        }
    }
}
