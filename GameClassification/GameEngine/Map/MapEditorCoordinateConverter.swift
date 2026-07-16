import CoreGraphics
import Observation
import SpriteKit

@MainActor
@Observable
final class MapEditorCoordinateConverter {
    static let minimumCameraScale: CGFloat = 0.25
    static let maximumCameraScale: CGFloat = 3.5

    private weak var view: SKView?
    private weak var scene: SKScene?
    private weak var camera: SKCameraNode?
    private(set) var revision = 0
    private(set) var viewportSize = CGSize.zero

    func attach(view: SKView, scene: SKScene, camera: SKCameraNode) {
        self.view = view
        self.scene = scene
        self.camera = camera
        viewportSize = view.bounds.size
        revision += 1
    }

    func detach(scene: SKScene) {
        guard self.scene === scene else { return }
        view = nil
        self.scene = nil
        camera = nil
        revision += 1
    }

    func refresh() {
        if let view { viewportSize = view.bounds.size }
        revision &+= 1
    }

    func screenToWorld(_ screenPoint: CGPoint) -> CGPoint? {
        guard let scene, let view,
              view.bounds.insetBy(dx: -1, dy: -1).contains(screenPoint) else { return nil }
        return scene.convertPoint(fromView: screenPoint)
    }

    func worldToScreen(_ worldPoint: CGPoint) -> CGPoint? {
        guard let scene else { return nil }
        return scene.convertPoint(toView: worldPoint)
    }

    func screenRect(from worldRect: CGRect) -> CGRect? {
        guard let topLeft = worldToScreen(CGPoint(x: worldRect.minX, y: worldRect.maxY)),
              let bottomRight = worldToScreen(CGPoint(x: worldRect.maxX, y: worldRect.minY)) else { return nil }
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
    }

    func visibleWorldRect() -> CGRect? {
        guard viewportSize.width > 0, viewportSize.height > 0,
              let a = screenToWorld(.zero),
              let b = screenToWorld(CGPoint(x: viewportSize.width, y: viewportSize.height)) else { return nil }
        return CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    func panCamera(screenTranslation: CGSize, worldSize: CGSize) {
        guard let camera,
              let start = screenToWorld(.zero),
              let translated = screenToWorld(CGPoint(x: screenTranslation.width, y: screenTranslation.height)) else { return }
        camera.position = clampedCameraPosition(
            CGPoint(
                x: camera.position.x - (translated.x - start.x),
                y: camera.position.y - (translated.y - start.y)
            ),
            camera: camera,
            worldSize: worldSize
        )
        refresh()
    }

    func zoomCamera(multiplier: CGFloat, worldSize: CGSize) {
        guard let camera, multiplier.isFinite, multiplier > 0 else { return }
        setCameraScale(camera.xScale / multiplier, worldSize: worldSize)
    }

    /// A user-facing zoom level where `1` is a 1:1 camera scale and larger
    /// values magnify the map. This is intentionally the inverse of SpriteKit's
    /// camera scale so the editor control behaves like a conventional zoom UI.
    var cameraZoomLevel: CGFloat {
        guard let camera, camera.xScale > 0 else { return 1 }
        return 1 / camera.xScale
    }

    func setCameraZoomLevel(_ zoomLevel: CGFloat, worldSize: CGSize) {
        guard zoomLevel.isFinite, zoomLevel > 0 else { return }
        setCameraScale(1 / zoomLevel, worldSize: worldSize)
    }

    private func setCameraScale(_ scale: CGFloat, worldSize: CGSize) {
        guard let camera, scale.isFinite else { return }
        let newScale = min(max(scale, Self.minimumCameraScale), Self.maximumCameraScale)
        camera.setScale(newScale)
        camera.position = clampedCameraPosition(camera.position, camera: camera, worldSize: worldSize)
        refresh()
    }

    private func clampedCameraPosition(
        _ position: CGPoint,
        camera: SKCameraNode,
        worldSize: CGSize
    ) -> CGPoint {
        CameraFollowMath.clampedTarget(
            playerPosition: position,
            viewportSize: viewportSize,
            cameraScale: camera.xScale,
            worldSize: worldSize
        )
    }
}
