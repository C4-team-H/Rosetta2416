#if DEBUG
import SwiftUI
import UIKit

struct MapDebugOverlayView: View {
    let viewModel: MapDebugViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var dragIsActive = false
    @State private var didConfigureCompactLayout = false
    @State private var lastCameraDragTranslation = CGSize.zero
    @State private var lastCameraDragStartLocation: CGPoint?
    @State private var lastMagnification: CGFloat = 1

    var body: some View {
        if DebugAvailability.isMapEditorAvailable {
            overlayContent
        }
    }

    private var overlayContent: some View {
        ZStack {
            if viewModel.settings.isMapDebugEnabled {
                editorContent
            } else {
                enableButton
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingSettings },
            set: { viewModel.isShowingSettings = $0 }
        )) { MapDebugSettingsView(viewModel: viewModel) }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingValidation },
            set: { viewModel.isShowingValidation = $0 }
        )) { MapDebugValidationView(viewModel: viewModel) }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingExport },
            set: { viewModel.isShowingExport = $0 }
        )) { MapDebugExportView(viewModel: viewModel) }
        .sheet(isPresented: Binding(
            get: { horizontalSizeClass == .compact && viewModel.isShowingLayers },
            set: { viewModel.isShowingLayers = $0 }
        )) { MapDebugLayerControls(viewModel: viewModel).padding() }
        .sheet(isPresented: Binding(
            get: { horizontalSizeClass == .compact && viewModel.isShowingInspector },
            set: { viewModel.isShowingInspector = $0 }
        )) { MapDebugInspectorView(viewModel: viewModel).padding() }
        .sheet(isPresented: Binding(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { viewModel.shareURL = nil } }
        )) {
            if let url = viewModel.shareURL { MapDebugShareSheet(url: url) }
        }
        .confirmationDialog(
            "Delete selected map element?",
            isPresented: Binding(
                get: { viewModel.pendingDelete != nil },
                set: { if !$0 { viewModel.pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { viewModel.deletePendingElement() }
            Button("Cancel", role: .cancel) { viewModel.pendingDelete = nil }
        }
        .alert("Map Debug Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onAppear {
            guard horizontalSizeClass == .compact, !didConfigureCompactLayout else { return }
            didConfigureCompactLayout = true
            viewModel.isShowingLayers = false
            viewModel.isShowingInspector = false
        }
        .onChange(of: viewModel.settings.editorMode) { _, _ in
            resetCameraDragState()
        }
        .onChange(of: viewModel.settings.isMapDebugEnabled) { _, _ in
            resetCameraDragState()
        }
        .onDisappear {
            resetCameraDragState()
        }
    }

    private func resetCameraDragState() {
        lastCameraDragTranslation = .zero
        lastCameraDragStartLocation = nil
    }

    private var enableButton: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.settings.editorMode = .navigate
                viewModel.settings.isMapDebugEnabled = true
            } label: {
                Label("DEBUG MAP", systemImage: "hammer.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(.yellow, in: .capsule)
            }
            Button {
                viewModel.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.75), in: .circle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .safeAreaPadding(.top, 142)
        .safeAreaPadding(.trailing, 16)
    }

    private var editorContent: some View {
        GeometryReader { geometry in
            ZStack {
                MapDebugCanvas(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .allowsHitTesting(viewModel.settings.editorMode != .testCollision)
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { value in
                            guard viewModel.settings.editorMode != .navigate else { return }
                            viewModel.tap(screenPoint: value.location)
                        }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .local)
                            .onChanged { value in
                                if viewModel.settings.editorMode == .navigate {
                                    if lastCameraDragStartLocation != value.startLocation {
                                        lastCameraDragStartLocation = value.startLocation
                                        lastCameraDragTranslation = .zero
                                    }
                                    let incrementalTranslation = CGSize(
                                        width: value.translation.width - lastCameraDragTranslation.width,
                                        height: value.translation.height - lastCameraDragTranslation.height
                                    )
                                    lastCameraDragTranslation = value.translation
                                    viewModel.panCamera(screenTranslation: incrementalTranslation)
                                    return
                                }
                                if !dragIsActive {
                                    dragIsActive = true
                                    viewModel.beginDrag(screenPoint: value.startLocation)
                                }
                                viewModel.updateDrag(screenPoint: value.location)
                            }
                            .onEnded { value in
                                if viewModel.settings.editorMode == .navigate {
                                    resetCameraDragState()
                                    return
                                }
                                viewModel.endDrag(screenPoint: value.location)
                                dragIsActive = false
                            }
                    )
                    .simultaneousGesture(
                        MagnifyGesture(minimumScaleDelta: 0.005)
                            .onChanged { value in
                                let magnification = value.magnification
                                guard magnification.isFinite,
                                      magnification > 0,
                                      lastMagnification.isFinite,
                                      lastMagnification > 0 else { return }
                                let incrementalMultiplier = magnification / lastMagnification
                                lastMagnification = magnification
                                viewModel.zoomCamera(multiplier: incrementalMultiplier)
                            }
                            .onEnded { _ in
                                lastMagnification = 1
                            }
                    )

                if viewModel.settings.editorMode != .navigate
                    && viewModel.settings.editorMode != .testCollision {
                    MapDebugCameraGestureBridge(
                        onPan: viewModel.panCamera(screenTranslation:)
                    )
                    .allowsHitTesting(false)
                }

                VStack(spacing: 8) {
                    MapDebugToolbar(viewModel: viewModel)
                    cameraControls
                    Spacer()
                    statusBar
                }
                .padding(.horizontal, 12)
                .safeAreaPadding(.vertical, 8)

                if viewModel.isShowingLayers, horizontalSizeClass != .compact {
                    MapDebugLayerControls(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.top, 92)
                }

                if viewModel.isShowingInspector, horizontalSizeClass != .compact {
                    MapDebugInspectorView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 12)
                        .padding(.top, 92)
                        .padding(.bottom, 72)
                } else {
                    Button {
                        viewModel.isShowingInspector = true
                    } label: {
                        Image(systemName: "sidebar.right")
                            .padding(10)
                            .background(.black.opacity(0.8), in: .circle)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var cameraControls: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.zoomCamera(multiplier: 0.8)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }

            Slider(
                value: Binding(
                    get: { viewModel.cameraZoomLevel },
                    set: { viewModel.setCameraZoomLevel($0) }
                ),
                in: viewModel.cameraZoomRange
            )
            .frame(width: 150)
            .accessibilityLabel("Map zoom")

            Button {
                viewModel.zoomCamera(multiplier: 1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }

            Button("1:1") {
                viewModel.setCameraZoomLevel(1)
            }
            .font(.caption.monospaced().bold())

            Text("\(Int((viewModel.cameraZoomLevel * 100).rounded()))%")
                .font(.caption.monospaced().bold())
                .frame(minWidth: 44, alignment: .trailing)

            Text("Pan: 1 jari/Pencil  •  Zoom: pinch/slider")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .buttonStyle(.bordered)
        .tint(.cyan)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.86), in: .capsule)
        .overlay { Capsule().stroke(.cyan.opacity(0.35)) }
        .accessibilityElement(children: .contain)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(viewModel.statusTitle)
                .font(.caption.bold())
                .foregroundStyle(viewModel.settings.editorMode == .testCollision ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewModel.settings.editorMode == .testCollision ? Color.yellow : Color.red, in: .capsule)

            Text(viewModel.store.source.displayName)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.cyan)

            if viewModel.store.isDirty { Text("UNSAVED").font(.caption2.bold()).foregroundStyle(.orange) }

            if let point = viewModel.cursorWorldPosition {
                Text("X \(point.x, format: .number.precision(.fractionLength(1)))  Y \(point.y, format: .number.precision(.fractionLength(1)))")
                    .font(.caption.monospaced())
            }

            Spacer()
            Label("\(viewModel.store.validation.errors.count)", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            Label("\(viewModel.store.validation.warnings.count)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Button("Rebuild Collision") { viewModel.rebuildCollision() }
            Button("Reset Player") { viewModel.onResetPlayerToSpawn?() }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.86), in: .rect(cornerRadius: 11))
    }
}

private struct MapDebugCanvas: View {
    let viewModel: MapDebugViewModel

    var body: some View {
        let _ = viewModel.converter.revision
        Canvas { context, _ in
            if viewModel.settings.showGrid { drawGrid(context: &context) }
            for element in viewModel.visibleElements { draw(element, context: &context) }
            if let preview = viewModel.createPreviewFrame,
               let screen = viewModel.converter.screenRect(from: preview) {
                let path = Path(screen)
                context.fill(path, with: .color(.white.opacity(0.12)))
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            drawPlayerFootprint(context: &context)
            drawSelection(context: &context)
        }
        .ignoresSafeArea()
    }

    private func drawGrid(context: inout GraphicsContext) {
        guard let visible = viewModel.converter.visibleWorldRect() else { return }
        let step = max(1, CGFloat(viewModel.settings.gridSize))
        let major = step * 5
        var minorPath = Path()
        var majorPath = Path()
        let startX = floor(visible.minX / step) * step
        let startY = floor(visible.minY / step) * step

        for x in stride(from: startX, through: visible.maxX + step, by: step) {
            guard let a = viewModel.converter.worldToScreen(CGPoint(x: x, y: visible.minY)),
                  let b = viewModel.converter.worldToScreen(CGPoint(x: x, y: visible.maxY)) else { continue }
            if abs(x.truncatingRemainder(dividingBy: major)) < 0.01 {
                majorPath.move(to: a); majorPath.addLine(to: b)
            } else {
                minorPath.move(to: a); minorPath.addLine(to: b)
            }
        }
        for y in stride(from: startY, through: visible.maxY + step, by: step) {
            guard let a = viewModel.converter.worldToScreen(CGPoint(x: visible.minX, y: y)),
                  let b = viewModel.converter.worldToScreen(CGPoint(x: visible.maxX, y: y)) else { continue }
            if abs(y.truncatingRemainder(dividingBy: major)) < 0.01 {
                majorPath.move(to: a); majorPath.addLine(to: b)
            } else {
                minorPath.move(to: a); minorPath.addLine(to: b)
            }
        }
        context.stroke(minorPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        context.stroke(majorPath, with: .color(.white.opacity(0.20)), lineWidth: 1)

        if let origin = viewModel.converter.worldToScreen(.zero) {
            context.fill(Path(ellipseIn: CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)), with: .color(.white))
        }
    }

    private func draw(_ element: MapGeometryElement, context: inout GraphicsContext) {
        let color = color(for: element)
        if case let .blockedArea(area) = element,
           draw(area.shape, color: color, label: element, context: &context) {
            return
        }
        if let points = element.freeformVertices,
           let path = screenPath(points: points, closes: true) {
            context.fill(path, with: .color(color.opacity(0.14)))
            context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1.5)
            if let frame = element.worldFrame,
               let center = viewModel.converter.worldToScreen(
                CGPoint(x: frame.midX, y: frame.midY)
               ) {
                drawLabel(element, at: center, context: &context)
            }
            return
        }
        if let rotated = rotatedRectangle(for: element) {
            let points = rotatedRectangleCorners(
                frame: rotated.frame,
                center: rotated.center,
                rotation: rotated.rotation
            )
            if let path = screenPath(points: points, closes: true) {
                context.fill(path, with: .color(color.opacity(0.14)))
                context.stroke(
                    path,
                    with: .color(color.opacity(0.9)),
                    lineWidth: element.id.category == .wall ? 2.5 : 1.5
                )
                if let center = viewModel.converter.worldToScreen(rotated.center) {
                    drawLabel(element, at: center, context: &context)
                }
                return
            }
        }
        if let frame = element.worldFrame,
           let screenFrame = viewModel.converter.screenRect(from: frame) {
            let path = Path(screenFrame)
            context.fill(path, with: .color(color.opacity(0.14)))
            context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: element.id.category == .wall ? 2.5 : 1.5)
            drawLabel(element, at: CGPoint(x: screenFrame.midX, y: screenFrame.midY), context: &context)
        } else if let screen = viewModel.converter.worldToScreen(element.worldPosition) {
            let radius: CGFloat = element.id.category == .spawnPoint ? 9 : 7
            var cross = Path()
            cross.move(to: CGPoint(x: screen.x - radius, y: screen.y)); cross.addLine(to: CGPoint(x: screen.x + radius, y: screen.y))
            cross.move(to: CGPoint(x: screen.x, y: screen.y - radius)); cross.addLine(to: CGPoint(x: screen.x, y: screen.y + radius))
            context.stroke(cross, with: .color(color), lineWidth: 2)
            context.stroke(Path(ellipseIn: CGRect(x: screen.x - radius, y: screen.y - radius, width: radius * 2, height: radius * 2)), with: .color(color), lineWidth: 1.5)
            drawLabel(element, at: CGPoint(x: screen.x, y: screen.y - 18), context: &context)
        }
    }

    @discardableResult
    private func draw(
        _ shape: MapGeometryShape,
        color: Color,
        label: MapGeometryElement,
        context: inout GraphicsContext
    ) -> Bool {
        switch shape {
        case .rectangle:
            return false
        case let .polygon(points), let .edgeChain(points):
            let closes: Bool
            if case .polygon = shape { closes = true } else { closes = false }
            guard let path = screenPath(points: points.map(\.cgPoint), closes: closes) else { return false }
            if closes { context.fill(path, with: .color(color.opacity(0.14))) }
            context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 2.5)
            if let center = viewModel.converter.worldToScreen(label.worldPosition) {
                drawLabel(label, at: center, context: &context)
            }
            return true
        }
    }

    private func screenPath(points: [CGPoint], closes: Bool) -> Path? {
        guard let firstWorld = points.first,
              let first = viewModel.converter.worldToScreen(firstWorld) else { return nil }
        var path = Path()
        path.move(to: first)
        for worldPoint in points.dropFirst() {
            guard let point = viewModel.converter.worldToScreen(worldPoint) else { continue }
            path.addLine(to: point)
        }
        if closes { path.closeSubpath() }
        return path
    }

    private func drawLabel(_ element: MapGeometryElement, at point: CGPoint, context: inout GraphicsContext) {
        guard viewModel.settings.showCoordinates else { return }
        var label = "\(element.id.rawValue)\nX \(Int(element.worldPosition.x)) Y \(Int(element.worldPosition.y))"
        if let frame = element.worldFrame { label += "  W \(Int(frame.width)) H \(Int(frame.height))" }
        context.draw(
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white),
            at: point,
            anchor: .center
        )
    }

    private func drawSelection(context: inout GraphicsContext) {
        guard let selected = viewModel.selectedElement else { return }
        let vertices = viewModel.vertexScreenPoints(for: selected)
        let isEditableShape: Bool = {
            if case let .blockedArea(area) = selected {
                switch area.shape {
                case .polygon, .edgeChain: return true
                case .rectangle: return false
                }
            }
            return false
        }()
        if !vertices.isEmpty,
           viewModel.settings.editorMode == .editNodes
            || viewModel.settings.editorMode == .addNode
            || viewModel.settings.editorMode == .deleteNode
            || isEditableShape {
            var outline = Path()
            outline.move(to: vertices[0])
            vertices.dropFirst().forEach { outline.addLine(to: $0) }
            if shouldCloseNodeOutline(for: selected) { outline.closeSubpath() }
            context.stroke(outline, with: .color(.white), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            if viewModel.settings.editorMode == .resize
                || viewModel.settings.editorMode == .editNodes
                || viewModel.settings.editorMode == .addNode
                || viewModel.settings.editorMode == .deleteNode {
                for (index, point) in vertices.enumerated() {
                    let handle = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
                    let isSelected = viewModel.activeVertexIndex == index
                        || viewModel.selectedVertexIndex == index
                    context.fill(Path(ellipseIn: handle), with: .color(isSelected ? .cyan : .white))
                    context.stroke(Path(ellipseIn: handle), with: .color(.black), lineWidth: 2)
                    context.draw(
                        Text("\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black),
                        at: point,
                        anchor: .center
                    )
                }
            }
            return
        }
        if let rotated = rotatedRectangle(for: selected) {
            let worldPoints = rotatedRectangleCorners(
                frame: rotated.frame,
                center: rotated.center,
                rotation: rotated.rotation
            )
            guard let outline = screenPath(points: worldPoints, closes: true) else { return }
            context.stroke(outline, with: .color(.white), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            if viewModel.settings.editorMode == .resize {
                for (_, point) in viewModel.handlePoints(for: selected) {
                    let handle = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                    context.fill(Path(handle), with: .color(.white))
                    context.stroke(Path(handle), with: .color(.black), lineWidth: 1)
                }
            }
            return
        }
        if let frame = selected.worldFrame,
           let screenFrame = viewModel.converter.screenRect(from: frame) {
            context.stroke(Path(screenFrame.insetBy(dx: -3, dy: -3)), with: .color(.white), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            if viewModel.settings.editorMode == .resize {
                for (_, point) in viewModel.handlePoints(for: selected) {
                    let handle = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                    context.fill(Path(handle), with: .color(.white))
                    context.stroke(Path(handle), with: .color(.black), lineWidth: 1)
                }
            }
        } else if let screen = viewModel.converter.worldToScreen(selected.worldPosition) {
            context.stroke(Path(ellipseIn: CGRect(x: screen.x - 15, y: screen.y - 15, width: 30, height: 30)), with: .color(.white), lineWidth: 3)
        }
    }

    private func shouldCloseNodeOutline(for element: MapGeometryElement) -> Bool {
        switch element {
        case .wall:
            return false
        case let .blockedArea(area):
            if case .edgeChain = area.shape { return false }
            return true
        case .room, .corridor, .doorway, .object:
            return true
        case .station, .spawnPoint, .checkpoint:
            return false
        }
    }

    private func rotatedRectangle(
        for element: MapGeometryElement
    ) -> (frame: CGRect, center: CGPoint, rotation: Double)? {
        switch element {
        case let .wall(wall)
            where wall.vertices == nil && abs(wall.rotationRadians) > 0.000_1:
            return (wall.frame.cgRect, element.worldPosition, wall.rotationRadians)
        case let .object(object)
            where object.vertices == nil && abs(object.rotation) > 0.000_1:
            return (object.frame, object.position.cgPoint, object.rotation)
        default:
            return nil
        }
    }

    private func drawPlayerFootprint(context: inout GraphicsContext) {
        guard viewModel.settings.showCollisionBodies else { return }
        let player = viewModel.sessionState.localPlayer.worldPosition
        let footprint = viewModel.store.configuration.playerFootprint.runtimeValue
        let center = footprint.center(at: player)
        let obstacleRadius = footprint.obstacleRadius
        let obstacleBounds = CGRect(
            x: center.x - obstacleRadius,
            y: center.y - obstacleRadius,
            width: obstacleRadius * 2,
            height: obstacleRadius * 2
        )
        if let obstacleScreenBounds = screenRect(from: obstacleBounds) {
            let obstaclePath = Path(ellipseIn: obstacleScreenBounds)
            context.fill(obstaclePath, with: .color(.orange.opacity(0.08)))
            context.stroke(
                obstaclePath,
                with: .color(.orange),
                style: StrokeStyle(lineWidth: 2, dash: [8, 5])
            )
        }

        let localBounds = PlayerNode.makeFootprintBounds(footprint: footprint)
        let worldBounds = localBounds.offsetBy(dx: player.x, dy: player.y)
        guard let screenBounds = screenRect(from: worldBounds) else { return }
        let footprintPath = Path { $0.addRect(screenBounds) }
        context.fill(footprintPath, with: .color(.green.opacity(0.12)))
        context.stroke(footprintPath, with: .color(.green), lineWidth: 2)

        if viewModel.settings.showCoordinates {
            context.draw(
                Text("playerFootprint\nW \(Int(footprint.width)) H \(Int(footprint.height))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green),
                at: CGPoint(x: screenBounds.midX, y: screenBounds.maxY + 16),
                anchor: .center
            )
            if let centerScreen = viewModel.converter.worldToScreen(center) {
                context.draw(
                    Text("obstacleRadius \(Int(obstacleRadius))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange),
                    at: CGPoint(x: centerScreen.x, y: centerScreen.y - 22),
                    anchor: .center
                )
            }
        }

        drawPlayerCollisionHandles(context: &context)
    }

    private func screenRect(from worldRect: CGRect) -> CGRect? {
        guard let firstCorner = viewModel.converter.worldToScreen(CGPoint(x: worldRect.minX, y: worldRect.minY)),
              let secondCorner = viewModel.converter.worldToScreen(CGPoint(x: worldRect.maxX, y: worldRect.maxY)) else { return nil }
        return CGRect(
            x: min(firstCorner.x, secondCorner.x),
            y: min(firstCorner.y, secondCorner.y),
            width: abs(secondCorner.x - firstCorner.x),
            height: abs(secondCorner.y - firstCorner.y)
        )
    }

    private func drawPlayerCollisionHandles(context: inout GraphicsContext) {
        guard viewModel.settings.editorMode == .move || viewModel.settings.editorMode == .resize else { return }
        if let center = viewModel.playerCollisionCenterScreenPoint() {
            let isActive = viewModel.activePlayerCollisionHandle == .center
            let rect = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: rect), with: .color(isActive ? .cyan : .white))
            context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: 1.5)
        }

        guard viewModel.settings.editorMode == .resize else { return }
        for (handle, point) in viewModel.playerFootprintHandlePoints() {
            let isActive = viewModel.activePlayerCollisionHandle == .footprint(handle)
            let rect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
            context.fill(Path(rect), with: .color(isActive ? .cyan : .white))
            context.stroke(Path(rect), with: .color(.green), lineWidth: 1.5)
        }

        guard let center = viewModel.playerCollisionCenterScreenPoint(),
              let radiusHandle = viewModel.playerObstacleRadiusHandlePoint() else { return }
        var radiusLine = Path()
        radiusLine.move(to: center)
        radiusLine.addLine(to: radiusHandle)
        context.stroke(radiusLine, with: .color(.orange), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

        let isActive = viewModel.activePlayerCollisionHandle == .obstacleRadius
        let rect = CGRect(x: radiusHandle.x - 7, y: radiusHandle.y - 7, width: 14, height: 14)
        context.fill(Path(ellipseIn: rect), with: .color(isActive ? .cyan : .orange))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.5)
    }

    private func color(for element: MapGeometryElement) -> Color {
        if case let .doorway(doorway) = element {
            return doorway.defaultState == .open ? .yellow : Color(red: 1, green: 0, blue: 0.85)
        }
        return switch element.id.category {
        case .room: .green
        case .corridor: .cyan
        case .wall: .red
        case .doorway: .yellow
        case .blockedArea: Color(red: 1, green: 0, blue: 0.85)
        case .object: .orange
        case .missionStation: .purple
        case .foodStation: .blue
        case .spawnPoint: .white
        case .checkpoint: .yellow
        }
    }
}

private struct MapDebugCameraGestureBridge: UIViewRepresentable {
    let onPan: (CGSize) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPan: onPan) }

    func makeUIView(context: Context) -> UIView {
        let view = GestureAttachmentView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.installIfNeeded(on: uiView.superview)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class GestureAttachmentView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            coordinator?.installIfNeeded(on: superview)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (CGSize) -> Void
        private weak var installedView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?

        init(onPan: @escaping (CGSize) -> Void) {
            self.onPan = onPan
        }

        func installIfNeeded(on view: UIView?) {
            guard let view, installedView !== view else { return }
            uninstall()
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.allowedTouchTypes = [
                NSNumber(value: UITouch.TouchType.direct.rawValue),
                NSNumber(value: UITouch.TouchType.pencil.rawValue)
            ]
            pan.cancelsTouchesInView = false
            pan.delegate = self
            view.addGestureRecognizer(pan)
            installedView = view
            panRecognizer = pan
        }

        func uninstall() {
            if let panRecognizer { installedView?.removeGestureRecognizer(panRecognizer) }
            installedView = nil
            panRecognizer = nil
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            guard translation != .zero else { return }
            onPan(CGSize(width: translation.x, height: translation.y))
            recognizer.setTranslation(.zero, in: recognizer.view)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }
    }
}
#endif
