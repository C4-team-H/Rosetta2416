import UIKit

/// Lets gameplay touches pass through the full-screen hosting view while only the HUD button is visible.
final class MapOverlayContainerView: UIView {
    private let viewModel: TacticalMapViewModel

    init(viewModel: TacticalMapViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if viewModel.isMapPresented {
            return super.hitTest(point, with: event)
        }

        guard viewModel.isGameplayActive else { return nil }
        return mapButtonHitArea.contains(point) ? super.hitTest(point, with: event) : nil
    }

    private var mapButtonHitArea: CGRect {
        let hitSize: CGFloat = 84
        return CGRect(
            x: bounds.maxX - safeAreaInsets.right - hitSize,
            y: safeAreaInsets.top + 68,
            width: hitSize,
            height: hitSize
        )
    }
}
