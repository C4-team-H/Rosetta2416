import Foundation

struct MapGeometryRuntimeUpdate {
    let map: GameMap
    let changeSet: MapGeometryChangeSet
}

@MainActor
final class MapGeometryUpdateSystem: MapGeometryApplying {
    let store: MapGeometryStore
    private(set) var appliedRevision: Int

    init(store: MapGeometryStore) {
        self.store = store
        appliedRevision = -1
    }

    func apply(configuration: MapGeometryConfiguration) {
        store.replaceConfiguration(configuration, source: .debugDraft)
    }

    func update(element: MapGeometryElement) {
        store.update(element)
    }

    func remove(elementID: MapElementID) {
        _ = store.remove(elementID)
    }

    /// Called by GameScene at the beginning of update(_:). Multiple UI mutations
    /// before the frame are coalesced into the newest immutable snapshot.
    func drainLatestSnapshot() -> MapGeometryRuntimeUpdate? {
        guard appliedRevision != store.revision else { return nil }
        let map = GameMapLayout.makeRuntimeMap(
            from: store.configuration,
            revision: store.revision
        )
        appliedRevision = store.revision
        return MapGeometryRuntimeUpdate(
            map: map,
            changeSet: store.consumePendingChangeSet()
        )
    }
}
