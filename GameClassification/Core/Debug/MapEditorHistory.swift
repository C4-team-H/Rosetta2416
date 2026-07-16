import Foundation

final class MapEditorHistory {
    private let capacity: Int
    private var undoStack: [MapGeometryConfiguration] = []
    private var redoStack: [MapGeometryConfiguration] = []

    init(capacity: Int = 100) {
        self.capacity = max(1, capacity)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func record(_ configuration: MapGeometryConfiguration) {
        if undoStack.last != configuration {
            undoStack.append(configuration)
            if undoStack.count > capacity { undoStack.removeFirst(undoStack.count - capacity) }
        }
        redoStack.removeAll(keepingCapacity: true)
    }

    func undo(current: MapGeometryConfiguration) -> MapGeometryConfiguration? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    func redo(current: MapGeometryConfiguration) -> MapGeometryConfiguration? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
