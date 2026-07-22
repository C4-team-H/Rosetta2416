import SpriteKit

final class WorldLoader {
    func makeShipMapNode(
        map: GameMap,
        debugEnabled: Bool,
        doorStateDidChange: @escaping (DoorID, DoorState) -> Void
    ) -> ShipMapNode {
        ShipMapNode(
            map: map,
            debugEnabled: debugEnabled,
            doorStateDidChange: doorStateDidChange
        )
    }

    func makePlayerNode(
        configuration: GameMapConfiguration,
        debugEnabled: Bool
    ) -> PlayerNode {
        PlayerNode(configuration: configuration, debugEnabled: debugEnabled)
    }
}
