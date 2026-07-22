//
//  DrawingChallengeViewController.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 13/07/26.
//

import PencilKit
import Combine
import SwiftUI
import UIKit

class DrawingChallengeViewController: UIViewController, PKCanvasViewDelegate {

    // MARK: - Callbacks
    var onSuccess: (() -> Void)?
    var onCancel: (() -> Void)?
    var onSubmit: ((PKDrawing) async -> DrawingSubmissionOutcome)?

    // MARK: - Challenge Configuration
    // Diset oleh GameScene sebelum present. Default ini hanya placeholder dan
    // selalu ditimpa oleh tantangan aktif sebelum controller ditampilkan.
    var sessionState: GameSessionState?
    var challenge: DrawingChallenge = DrawingChallenge.foodPool[0]
    var challengeIndex: Int = 1   // Ronde ke-berapa (1-based) untuk ditampilkan ke user
    var totalChallenges: Int = 5  // Total ronde tantangan
    private lazy var challengeViewModel = DrawingChallengeViewModel(challenge: challenge)
    private let layoutState = DrawingChallengeLayoutState()
    private var hostingController: UIHostingController<DrawingMissionCanvasLayout>?

    // MARK: - UI Components
    private let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.backgroundColor = UIColor.white
        canvas.isOpaque = true
        return canvas
    }()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.65) // Dark overlay background

        setupViews()
        setupCanvas()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make the canvas the active first responder so Apple Pencil events and
        // system Pencil features are routed to it reliably. Does not show any
        // extra UI because no PKToolPicker is attached.
        canvasView.becomeFirstResponder()
    }

    // MARK: - Layout Setup
    private func setupViews() {
        let rootView = DrawingMissionCanvasLayout(
            session: sessionState,
            challenge: challenge,
            challengeIndex: challengeIndex,
            totalChallenges: totalChallenges,
            canvasView: canvasView,
            layoutState: layoutState,
            onCancel: { [weak self] in self?.cancelTapped() },
            onClear: { [weak self] in self?.clearTapped() },
            onSubmit: { [weak self] in self?.submitTapped() }
        )
        let controller = UIHostingController(rootView: rootView)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(controller)
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func setupCanvas() {
        // Delegate tracks drawing changes (hook for save/restore via
        // drawing.dataRepresentation() / PKDrawing(data:)).
        canvasView.delegate = self

        // Setup PencilKit inking tool
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 6.0)

        // Accept both Apple Pencil and finger input. PencilKit captures
        // pressure, tilt, azimuth, and predicted/coalesced touches for Pencil
        // strokes automatically; no custom touch handling is needed.
        canvasView.drawingPolicy = .anyInput
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // canvasView.drawing is the source of truth for all strokes.
        // This is the hook for save/restore: serialize with
        // canvasView.drawing.dataRepresentation() and restore with
        // PKDrawing(data:). No manual stroke is added here, so Pencil and
        // finger strokes never duplicate.
    }

    // MARK: - Actions
    @objc private func cancelTapped() {
        AudioManager.shared.playBackSound()
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    @objc private func clearTapped() {
        AudioManager.shared.playEraseSound()
        clearCanvas()
    }

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
    }

    @objc private func submitTapped() {
        AudioManager.shared.playButtonSound()
        guard !canvasView.drawing.bounds.isEmpty else {
            showAlert(title: "Empty Canvas", message: "Please draw the \(challenge.displayName) before submitting.")
            return
        }
        guard let onSubmit else {
            showAlert(title: "Error", message: "The challenge has not been configured.")
            return
        }

        layoutState.isSubmitEnabled = false
        challengeViewModel.submissionHandler = onSubmit

        let drawing = canvasView.drawing
        Task { [weak self] in
            guard let self else { return }
            let outcome = await challengeViewModel.submit(drawing)
            if outcome.accepted {
                AudioManager.shared.playCorrectSound()
                showSuccessAlert()
            } else {
                AudioManager.shared.playWrongSound()
                if outcome.hasAlbumHint {
                    dismiss(animated: true) { [weak self] in
                        self?.onCancel?()
                    }
                } else {
                    showFailureAlert(message: outcome.message)
                }
            }
        }
    }

    // MARK: - Alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            AudioManager.shared.playButtonSound()
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showSuccessAlert() {
        let isLast = challengeIndex >= totalChallenges
        let title = isLast ? "All Challenges Completed!" : "Correct!"
        let message: String
        if isLast {
            message = "Awesome! You completed all \(totalChallenges) drawing challenges!"
        } else {
            message = "Great job! Your \(challenge.displayName) was recognized. Challenge \(challengeIndex) of \(totalChallenges) completed."
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { [weak self] _ in
            AudioManager.shared.playButtonSound()
            self?.dismiss(animated: true) {
                self?.onSuccess?()
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showFailureAlert(message: String? = nil) {
        let alert = UIAlertController(title: "Not Quite Right", message: message ?? "Your drawing wasn't recognized as a \(challenge.displayName). Please try drawing it again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .default, handler: { [weak self] _ in
            AudioManager.shared.playButtonSound()
            self?.challengeViewModel.retry()
            self?.layoutState.isSubmitEnabled = true
            self?.clearCanvas()
        }))
        present(alert, animated: true, completion: nil)
    }
}

private final class DrawingChallengeLayoutState: ObservableObject {
    @Published var isSubmitEnabled = true
}

private struct DrawingMissionCanvasLayout: View {
    let session: GameSessionState?
    let challenge: DrawingChallenge
    let challengeIndex: Int
    let totalChallenges: Int
    let canvasView: PKCanvasView
    @ObservedObject var layoutState: DrawingChallengeLayoutState
    let onCancel: () -> Void
    let onClear: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = DrawingMissionCanvasMetrics(size: proxy.size)

            ZStack {
                DrawingMissionBackdrop()

                Group {
                    if metrics.usesWideLayout {
                        HStack(alignment: .top, spacing: metrics.contentGap) {
                            sidebar(metrics: metrics)
                                .frame(width: metrics.sidebarWidth)

                            canvasColumn(metrics: metrics)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: metrics.contentGap) {
                            sidebar(metrics: metrics)
                                .frame(maxWidth: .infinity)

                            canvasColumn(metrics: metrics)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .padding(metrics.panelPadding)
                .frame(
                    maxWidth: metrics.panelMaxWidth,
                    maxHeight: metrics.panelMaxHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                        .fill(DrawingMissionPalette.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                                .stroke(DrawingMissionPalette.panelStroke, lineWidth: metrics.panelStrokeWidth)
                        )
                        .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 18)
                )
                .padding(metrics.outerPadding)

                if let session, session.showLowEnergyAlert {
                    LowEnergyAlertOverlay(session: session) {
                        session.dismissLowEnergyAlert()
                    }
                    .zIndex(99)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func sidebar(metrics: DrawingMissionCanvasMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sidebarGap) {
            Text(">_<")
                .font(.system(size: metrics.logoFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(DrawingMissionPalette.paper)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -metrics.panelPadding - metrics.sidebarGap)
            DrawingMissionInfoStrip(
                text: "CATEGORY : \(challenge.category.sidebarTitle)",
                fontSize: metrics.categoryFontSize
            )

            DrawingMissionTargetPanel(
                title: "DRAW",
                target: challenge.displayName,
                metrics: metrics
            )

            DrawingMissionInstructionPanel(
                challengeIndex: challengeIndex,
                totalChallenges: totalChallenges,
                target: challenge.displayName,
                metrics: metrics
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func canvasColumn(metrics: DrawingMissionCanvasMetrics) -> some View {
        VStack(spacing: metrics.buttonGap) {
            PencilCanvasHost(canvasView: canvasView)
                .background(DrawingMissionPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: metrics.canvasCornerRadius, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: metrics.buttonGap) {
                DrawingMissionButton(
                    title: "CANCEL",
                    background: DrawingMissionPalette.cancel,
                    isEnabled: true,
                    action: onCancel
                )

                DrawingMissionButton(
                    title: "CLEAR",
                    background: DrawingMissionPalette.clear,
                    isEnabled: true,
                    action: onClear
                )

                DrawingMissionButton(
                    title: "SUBMIT",
                    background: DrawingMissionPalette.submit,
                    isEnabled: layoutState.isSubmitEnabled,
                    action: onSubmit
                )
            }
            .frame(height: metrics.buttonHeight)
        }
    }
}

private struct PencilCanvasHost: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

private struct DrawingMissionInfoStrip: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(GameFont.custom(size: fontSize, weight: 800).font)
            .foregroundStyle(DrawingMissionPalette.paper)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .frame(height: max(42, fontSize * 2.5))
            .background(DrawingMissionPalette.sidebarBlock)
    }
}

private struct DrawingMissionTargetPanel: View {
    let title: String
    let target: String
    let metrics: DrawingMissionCanvasMetrics

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(GameFont.custom(size: metrics.drawLabelFontSize, weight: 800).font)
                .foregroundStyle(DrawingMissionPalette.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(target)
                .font(GameFont.custom(size: metrics.targetFontSize, weight: 400).font)
                .foregroundStyle(DrawingMissionPalette.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: metrics.targetPanelHeight)
        .background(DrawingMissionPalette.sidebarBlock)
    }
}

private struct DrawingMissionInstructionPanel: View {
    let challengeIndex: Int
    let totalChallenges: Int
    let target: String
    let metrics: DrawingMissionCanvasMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.instructionLineGap) {
            Text("EXTRA")
            Text("INSTRUCTIONS")

            Spacer(minLength: metrics.instructionSpacer)

            Text("ROUND \(challengeIndex) / \(max(totalChallenges, 1))")
            Text("TARGET LOCK : \(target)")
            Text("KEEP LINES BOLD")
        }
        .font(GameFont.custom(size: metrics.instructionFontSize, weight: 800).font)
        .foregroundStyle(DrawingMissionPalette.paper)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    DrawingMissionPalette.sidebarBlock.opacity(0.98),
                    DrawingMissionPalette.sidebarBlockBottom.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct DrawingMissionButtonStyle: ButtonStyle {
    let background: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background.opacity(isEnabled ? 1 : 0.55))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.35 : 0.78),
                radius: configuration.isPressed ? 2 : 0,
                x: configuration.isPressed ? 2 : 8,
                y: configuration.isPressed ? 2 : 8
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct DrawingMissionButton: View {
    let title: String
    let background: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GameFont.custom(size: 25, weight: 800).font)
                .foregroundStyle(DrawingMissionPalette.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(DrawingMissionButtonStyle(background: background, isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct DrawingMissionBackdrop: View {
    var body: some View {
        ZStack {
            DrawingMissionPalette.backdrop
            DrawingMissionPalette.backdropTexture.opacity(0.26)
                .blendMode(.screen)
        }
    }
}

private struct DrawingMissionCanvasMetrics {
    let size: CGSize

    var usesWideLayout: Bool {
        size.width >= 820 && size.width > size.height * 1.05
    }

    var outerPadding: CGFloat {
        clamp(size.width * 0.038, min: 20, max: 56)
    }

    var panelPadding: CGFloat {
        clamp(size.width * 0.034, min: 18, max: 52)
    }

    var panelMaxWidth: CGFloat {
        max(320, size.width - outerPadding * 2)
    }

    var panelMaxHeight: CGFloat {
        max(440, size.height - outerPadding * 2)
    }

    var sidebarWidth: CGFloat {
        clamp(size.width * 0.255, min: 230, max: 365)
    }

    var contentGap: CGFloat {
        clamp(size.width * 0.02, min: 14, max: 32)
    }

    var sidebarGap: CGFloat {
        clamp(size.height * 0.016, min: 10, max: 22)
    }

    var buttonGap: CGFloat {
        clamp(size.width * 0.016, min: 12, max: 28)
    }

    var buttonHeight: CGFloat {
        clamp(size.height * 0.092, min: 50, max: 88)
    }

    var targetPanelHeight: CGFloat {
        clamp(size.height * 0.112, min: 74, max: 126)
    }

    var logoFontSize: CGFloat {
        clamp(size.width * 0.18, min: 72, max: 200)
    }

    var categoryFontSize: CGFloat {
        clamp(size.width * 0.018, min: 13, max: 24)
    }

    var drawLabelFontSize: CGFloat {
        clamp(size.width * 0.02, min: 15, max: 28)
    }

    var targetFontSize: CGFloat {
        clamp(size.width * 0.041, min: 29, max: 62)
    }

    var instructionFontSize: CGFloat {
        clamp(size.width * 0.019, min: 15, max: 28)
    }

    var instructionLineGap: CGFloat {
        clamp(size.height * 0.01, min: 5, max: 12)
    }

    var instructionSpacer: CGFloat {
        clamp(size.height * 0.03, min: 12, max: 34)
    }

    var panelCornerRadius: CGFloat {
        clamp(size.width * 0.016, min: 12, max: 24)
    }

    var panelStrokeWidth: CGFloat {
        clamp(size.width * 0.006, min: 4, max: 10)
    }

    var canvasCornerRadius: CGFloat {
        clamp(size.width * 0.004, min: 2, max: 5)
    }

    var hardShadowOffset: CGFloat {
        clamp(size.width * 0.006, min: 5, max: 10)
    }

    private func clamp(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

private enum DrawingMissionPalette {
    static let backdrop = Color(red: 0.16, green: 0.22, blue: 0.27)
    static let backdropTexture = Color(red: 0.34, green: 0.43, blue: 0.49)
    static let panel = Color(red: 0.02, green: 0.04, blue: 0.05)
    static let panelStroke = Color(red: 0.08, green: 0.16, blue: 0.20)
    static let sidebarBlock = Color(red: 0.17, green: 0.23, blue: 0.28)
    static let sidebarBlockBottom = Color(red: 0.24, green: 0.31, blue: 0.35)
    static let paper = Color.white
    static let canvasStroke = Color(red: 0.78, green: 0.86, blue: 0.90)
    static let cancel = Color(red: 0.72, green: 0.16, blue: 0.23)
    static let clear = Color(red: 0.55, green: 0.60, blue: 0.61)
    static let submit = Color(red: 0.10, green: 0.36, blue: 0.37)
}

private extension DrawingCategory {
    var sidebarTitle: String {
        switch self {
        case .animal: "ANIMAL"
        case .plant: "PLANT"
        case .human: "HUMAN"
        case .landscape: "LANDSCAPE"
        case .transportation: "TRANSPORT"
        case .otherObject: "OBJECT"
        case .tool: "TOOL"
        case .equipment: "EQUIPMENT"
        case .furniture: "FURNITURE"
        case .electronics: "ELECTRONICS"
        case .weapon: "WEAPON"
        case .celestial: "CELESTIAL"
        case .food: "KITCHEN"
        }
    }
}
