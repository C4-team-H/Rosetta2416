import UIKit

/// Lets gameplay touches pass through the full-screen hosting view while only the HUD button is visible.
final class MapOverlayContainerView: UIView {
    private let viewModel: TacticalMapViewModel
    private let debugSettings: GameDebugSettings

    init(viewModel: TacticalMapViewModel, debugSettings: GameDebugSettings) {
        self.viewModel = viewModel
        self.debugSettings = debugSettings
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        #if DEBUG
        if DebugAvailability.isMapEditorAvailable && debugSettings.isMapDebugEnabled {
            if debugSettings.editorMode == .testCollision {
                return isInsideDebugChrome(point) ? super.hitTest(point, with: event) : nil
            }
            return super.hitTest(point, with: event)
        }
        if DebugAvailability.isMapEditorAvailable && debugButtonHitArea.contains(point) {
            return super.hitTest(point, with: event)
        }
        #endif

        if viewModel.isMapPresented {
            return super.hitTest(point, with: event)
        }

        if (viewModel.sessionState.currentDialogue != nil && viewModel.sessionState.phase == .playing) || viewModel.sessionState.showLowEnergyAlert {
            return super.hitTest(point, with: event)
        }

        if viewModel.sessionState.phase == .gameOver || viewModel.sessionState.phase == .victory || viewModel.sessionState.isPaused {
            return super.hitTest(point, with: event)
        }

        guard viewModel.isGameplayActive else { return nil }
        return mapButtonHitArea.contains(point) ? super.hitTest(point, with: event) : nil
    }

    private var mapButtonHitArea: CGRect {
        let hitWidth: CGFloat = 165
        let hitHeight: CGFloat = 84
        return CGRect(
            x: bounds.maxX - safeAreaInsets.right - hitWidth,
            y: safeAreaInsets.top + 68,
            width: hitWidth,
            height: hitHeight
        )
    }

    private var debugButtonHitArea: CGRect {
        CGRect(
            x: bounds.maxX - safeAreaInsets.right - 150,
            y: safeAreaInsets.top + 130,
            width: 150,
            height: 110
        )
    }

    private func isInsideDebugChrome(_ point: CGPoint) -> Bool {
        let top = CGRect(x: 0, y: 0, width: bounds.width, height: safeAreaInsets.top + 100)
        let bottom = CGRect(x: 0, y: bounds.height - safeAreaInsets.bottom - 86, width: bounds.width, height: safeAreaInsets.bottom + 86)
        guard bounds.width >= 700 else {
            return top.contains(point) || bottom.contains(point)
        }
        let left = CGRect(x: 0, y: 80, width: 235, height: bounds.height - 160)
        let right = CGRect(x: bounds.width - 345, y: 80, width: 345, height: bounds.height - 160)
        return [top, bottom, left, right].contains { $0.contains(point) }
    }
}
