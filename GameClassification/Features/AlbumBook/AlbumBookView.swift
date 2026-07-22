import SwiftUI

struct AlbumBookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AlbumBookViewModel()

    var body: some View {
        GeometryReader { proxy in
            let metrics = AlbumBookLayout(size: proxy.size)

            ZStack {
                AlbumBookSpaceBackground()

                HStack(spacing: metrics.columnSpacing) {
                    referenceIndex(metrics: metrics)
                        .frame(width: metrics.sidebarWidth)

                    referenceDetail(metrics: metrics)
                }
                .padding(metrics.screenInset)
            }
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
    }

    private func referenceIndex(metrics: AlbumBookLayout) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: metrics.compactHeight ? 6 : 10) {
                HStack(spacing: 9) {
                    Capsule()
                        .fill(AlbumBookPalette.crimson)
                        .frame(width: 42, height: 7)

                    Text("ROSETTA // 2416")
                        .font(GameFont.custom(size: metrics.eyebrowFontSize, weight: 700))
                        .tracking(1.5)
                        .foregroundStyle(AlbumBookPalette.paper.opacity(0.82))
                }

                Text("REFERENCE\nALBUM")
                    .font(GameFont.custom(size: metrics.sidebarTitleFontSize, weight: 700))
                    .foregroundStyle(AlbumBookPalette.paper)
                    .lineSpacing(-3)
                    .minimumScaleFactor(0.75)

                Text("157 OBJECT STUDIES")
                    .font(GameFont.custom(size: metrics.captionFontSize, weight: 600))
                    .tracking(1.2)
                    .foregroundStyle(AlbumBookPalette.sky)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, metrics.sidebarPadding)
            .padding(.top, metrics.sidebarPadding)
            .padding(.bottom, metrics.compactHeight ? 12 : 18)

            Rectangle()
                .fill(AlbumBookPalette.ink)
                .frame(height: 4)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AlbumBookPalette.paper.opacity(0.72))
                        .frame(height: 1)
                }

            searchField(metrics: metrics)
                .padding(.horizontal, metrics.sidebarPadding)
                .padding(.vertical, metrics.compactHeight ? 10 : 14)

            HStack {
                Text("ARCHIVE INDEX")
                Spacer()
                Text("\(viewModel.filteredLabels.count) FOUND")
            }
            .font(GameFont.custom(size: metrics.indexFontSize, weight: 700))
            .tracking(1)
            .foregroundStyle(AlbumBookPalette.paper.opacity(0.68))
            .padding(.horizontal, metrics.sidebarPadding)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 7) {
                    if viewModel.filteredLabels.isEmpty {
                        emptySearchState(metrics: metrics)
                    } else {
                        ForEach(Array(viewModel.filteredLabels.enumerated()), id: \.element) { index, label in
                            referenceRow(label: label, visibleIndex: index, metrics: metrics)
                        }
                    }
                }
                .padding(.horizontal, metrics.sidebarPadding)
                .padding(.bottom, metrics.sidebarPadding)
            }
            .scrollIndicators(.hidden)
        }
        .background(AlbumBookPalette.panel.opacity(0.97), in: .rect(cornerRadius: metrics.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                .strokeBorder(AlbumBookPalette.ink, lineWidth: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius - 3, style: .continuous)
                .strokeBorder(AlbumBookPalette.paper.opacity(0.78), lineWidth: 1)
                .padding(6)
        }
        .clipShape(.rect(cornerRadius: metrics.panelCornerRadius))
    }

    private func searchField(metrics: AlbumBookLayout) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: metrics.searchIconSize, weight: .bold))
                .foregroundStyle(AlbumBookPalette.sky)

            TextField("SEARCH 157 REFERENCES", text: $viewModel.searchText)
                .font(GameFont.custom(size: metrics.searchFontSize, weight: 600))
                .foregroundStyle(AlbumBookPalette.paper)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: metrics.searchIconSize, weight: .bold))
                        .foregroundStyle(AlbumBookPalette.paper.opacity(0.72))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: metrics.searchHeight)
        .background(AlbumBookPalette.ink.opacity(0.58), in: .rect(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(AlbumBookPalette.steelLight.opacity(0.72), lineWidth: 2)
        }
    }

    private func emptySearchState(metrics: AlbumBookLayout) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: metrics.compactHeight ? 24 : 30, weight: .medium))
                .foregroundStyle(AlbumBookPalette.sky)

            Text("NO REFERENCE FOUND")
                .font(GameFont.custom(size: metrics.searchFontSize, weight: 700))
                .tracking(1)
                .foregroundStyle(AlbumBookPalette.paper)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    private func referenceRow(
        label: String,
        visibleIndex: Int,
        metrics: AlbumBookLayout
    ) -> some View {
        let isSelected = viewModel.selectedLabel == label

        return Button {
            viewModel.selectedLabel = label
        } label: {
            HStack(spacing: 11) {
                Text(String(format: "%03d", canonicalIndex(for: label)))
                    .font(GameFont.custom(size: metrics.rowIndexFontSize, weight: 600))
                    .foregroundStyle(isSelected ? AlbumBookPalette.paper : AlbumBookPalette.sky.opacity(0.82))
                    .frame(width: 34, alignment: .leading)

                Rectangle()
                    .fill(isSelected ? AlbumBookPalette.paper : AlbumBookPalette.steelLight.opacity(0.48))
                    .frame(width: 2, height: 22)

                Text(label.uppercased())
                    .font(GameFont.custom(size: metrics.rowFontSize, weight: 700))
                    .foregroundStyle(AlbumBookPalette.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "scope")
                        .font(.system(size: metrics.rowAccessorySize, weight: .bold))
                        .foregroundStyle(AlbumBookPalette.paper)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: metrics.rowHeight, alignment: .leading)
            .background(
                isSelected ? AlbumBookPalette.green : AlbumBookPalette.steel.opacity(0.3),
                in: .rect(cornerRadius: 4)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isSelected ? AlbumBookPalette.paper.opacity(0.94) : AlbumBookPalette.steelLight.opacity(0.22),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(AlbumBookRowButtonStyle())
        .accessibilityLabel("Reference \(canonicalIndex(for: label)), \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id("\(visibleIndex)-\(label)")
    }

    private func referenceDetail(metrics: AlbumBookLayout) -> some View {
        VStack(spacing: metrics.compactHeight ? 10 : 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DRAWING REFERENCE")
                        .font(GameFont.custom(size: metrics.detailTitleFontSize, weight: 700))
                        .tracking(1.1)
                        .foregroundStyle(AlbumBookPalette.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("PLATE \(String(format: "%03d", selectedIndex)) / 157  •  VISUAL ARCHIVE")
                        .font(GameFont.custom(size: metrics.captionFontSize, weight: 600))
                        .tracking(0.8)
                        .foregroundStyle(AlbumBookPalette.sky)
                }

                Spacer(minLength: 8)

                Button("DONE") { dismiss() }
                    .font(GameFont.custom(size: metrics.doneFontSize, weight: 700))
                    .tracking(1.2)
                    .foregroundStyle(AlbumBookPalette.paper)
                    .frame(minWidth: metrics.doneWidth, minHeight: metrics.doneHeight)
                    .background(AlbumBookPalette.crimson, in: .rect(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(AlbumBookPalette.ink, lineWidth: 4)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(AlbumBookPalette.paper.opacity(0.92), lineWidth: 1)
                            .padding(5)
                    }
                    .buttonStyle(AlbumBookDoneButtonStyle())
                    .accessibilityHint("Closes the Album Book")
            }

            AlbumBookReferencePlate(
                imageName: viewModel.selectedLabel,
                label: viewModel.selectedLabel,
                compactHeight: metrics.compactHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED OBJECT")
                        .font(GameFont.custom(size: metrics.indexFontSize, weight: 700))
                        .tracking(1.3)
                        .foregroundStyle(AlbumBookPalette.sky)

                    Text(viewModel.selectedLabel.uppercased())
                        .font(GameFont.custom(size: metrics.selectedTitleFontSize, weight: 700))
                        .foregroundStyle(AlbumBookPalette.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    Circle()
                        .fill(AlbumBookPalette.greenBright)
                        .frame(width: 9, height: 9)

                    Text("REFERENCE ONLINE")
                        .font(GameFont.custom(size: metrics.indexFontSize, weight: 700))
                        .tracking(0.8)
                        .foregroundStyle(AlbumBookPalette.paper.opacity(0.82))
                }
            }
            .padding(.horizontal, metrics.detailFooterPadding)
            .frame(minHeight: metrics.detailFooterHeight)
            .background(AlbumBookPalette.panel.opacity(0.95), in: .rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(AlbumBookPalette.ink, lineWidth: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(AlbumBookPalette.steelLight.opacity(0.72), lineWidth: 1)
                    .padding(5)
            }
        }
        .padding(metrics.detailPadding)
        .background(AlbumBookPalette.deepPanel.opacity(0.93), in: .rect(cornerRadius: metrics.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                .strokeBorder(AlbumBookPalette.ink, lineWidth: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius - 3, style: .continuous)
                .strokeBorder(AlbumBookPalette.paper.opacity(0.44), lineWidth: 1)
                .padding(6)
        }
        .clipShape(.rect(cornerRadius: metrics.panelCornerRadius))
    }

    private var selectedIndex: Int {
        canonicalIndex(for: viewModel.selectedLabel)
    }

    private func canonicalIndex(for label: String) -> Int {
        (AlbumBookViewModel.allLabels.firstIndex(of: label) ?? 0) + 1
    }
}

private struct AlbumBookReferencePlate: View {
    let imageName: String
    let label: String
    let compactHeight: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AlbumBookPalette.steel)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AlbumBookPalette.paper)
                .padding(compactHeight ? 13 : 18)

            AlbumBookBlueprintGrid()
                .padding(compactHeight ? 18 : 23)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .padding(compactHeight ? 30 : 42)
                .accessibilityLabel("\(label) drawing reference")

            AlbumBookRivets()
                .padding(compactHeight ? 7 : 9)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(AlbumBookPalette.ink, lineWidth: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AlbumBookPalette.paper.opacity(0.86), lineWidth: 2)
                .padding(7)
        }
        .aspectRatio(1.45, contentMode: .fit)
    }
}

private struct AlbumBookBlueprintGrid: View {
    var body: some View {
        Canvas { context, size in
            let color = AlbumBookPalette.blueprint.opacity(0.12)
            let step = max(22, min(size.width, size.height) / 9)

            stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(color), lineWidth: 1)
            }

            stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(color), lineWidth: 1)
            }

            var crosshair = Path()
            crosshair.addEllipse(
                in: CGRect(
                    x: size.width * 0.5 - 30,
                    y: size.height * 0.5 - 30,
                    width: 60,
                    height: 60
                )
            )
            crosshair.move(to: CGPoint(x: size.width * 0.5 - 44, y: size.height * 0.5))
            crosshair.addLine(to: CGPoint(x: size.width * 0.5 + 44, y: size.height * 0.5))
            crosshair.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.5 - 44))
            crosshair.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.5 + 44))
            context.stroke(crosshair, with: .color(AlbumBookPalette.crimson.opacity(0.18)), lineWidth: 2)
        }
        .allowsHitTesting(false)
        .clipShape(.rect(cornerRadius: 4))
    }
}

private struct AlbumBookRivets: View {
    var body: some View {
        VStack {
            HStack {
                rivet
                Spacer()
                rivet
            }
            Spacer()
            HStack {
                rivet
                Spacer()
                rivet
            }
        }
        .allowsHitTesting(false)
    }

    private var rivet: some View {
        Circle()
            .fill(AlbumBookPalette.ink)
            .overlay {
                Circle()
                    .strokeBorder(AlbumBookPalette.paper.opacity(0.72), lineWidth: 1)
                    .padding(2)
            }
            .frame(width: 12, height: 12)
    }
}

private struct AlbumBookSpaceBackground: View {
    var body: some View {
        ZStack {
            AlbumBookPalette.space
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AlbumBookPalette.sky.opacity(0.1),
                    .clear,
                    AlbumBookPalette.ink.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                for index in 0..<82 {
                    let x = Self.unit(index * 17 + 3) * size.width
                    let y = Self.unit(index * 29 + 11) * size.height
                    let radius = index.isMultiple(of: 11) ? CGFloat(2.2) : CGFloat(0.8 + Self.unit(index + 7) * 1.2)
                    let starColor = index.isMultiple(of: 4)
                        ? AlbumBookPalette.sky.opacity(0.48)
                        : AlbumBookPalette.paper.opacity(0.56)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(starColor)
                    )

                    if index.isMultiple(of: 11) {
                        var flare = Path()
                        flare.move(to: CGPoint(x: x - 7, y: y))
                        flare.addLine(to: CGPoint(x: x + 7, y: y))
                        flare.move(to: CGPoint(x: x, y: y - 7))
                        flare.addLine(to: CGPoint(x: x, y: y + 7))
                        context.stroke(flare, with: .color(AlbumBookPalette.paper.opacity(0.62)), lineWidth: 1)
                    }
                }

                for index in 0..<18 {
                    let x = Self.unit(index * 41 + 5) * size.width
                    let y = Self.unit(index * 13 + 19) * size.height
                    let length = CGFloat(12 + Self.unit(index + 31) * 28)
                    var scratch = Path()
                    scratch.move(to: CGPoint(x: x, y: y))
                    scratch.addLine(to: CGPoint(x: x + length, y: y - length * 0.22))
                    context.stroke(
                        scratch,
                        with: .color(AlbumBookPalette.paper.opacity(0.055)),
                        lineWidth: 1
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private static func unit(_ seed: Int) -> CGFloat {
        let rawValue = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(rawValue - floor(rawValue))
    }
}

private struct AlbumBookRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct AlbumBookDoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .saturation(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct AlbumBookLayout {
    let size: CGSize

    var compactHeight: Bool { size.height < 520 }
    var screenInset: CGFloat { compactHeight ? 12 : 20 }
    var columnSpacing: CGFloat { compactHeight ? 10 : 16 }
    var sidebarWidth: CGFloat {
        min(max(size.width * (compactHeight ? 0.32 : 0.3), 270), 420)
    }
    var panelCornerRadius: CGFloat { compactHeight ? 8 : 11 }
    var sidebarPadding: CGFloat { compactHeight ? 14 : 18 }
    var detailPadding: CGFloat { compactHeight ? 13 : 20 }
    var detailFooterPadding: CGFloat { compactHeight ? 14 : 20 }
    var detailFooterHeight: CGFloat { compactHeight ? 48 : 64 }
    var searchHeight: CGFloat { compactHeight ? 44 : 48 }
    var rowHeight: CGFloat { compactHeight ? 44 : 46 }
    var doneWidth: CGFloat { compactHeight ? 82 : 100 }
    var doneHeight: CGFloat { compactHeight ? 44 : 48 }

    var eyebrowFontSize: CGFloat { compactHeight ? 9 : 11 }
    var sidebarTitleFontSize: CGFloat { compactHeight ? 25 : 34 }
    var detailTitleFontSize: CGFloat { compactHeight ? 20 : 27 }
    var selectedTitleFontSize: CGFloat { compactHeight ? 17 : 22 }
    var captionFontSize: CGFloat { compactHeight ? 9 : 11 }
    var indexFontSize: CGFloat { compactHeight ? 8 : 10 }
    var searchFontSize: CGFloat { compactHeight ? 10 : 12 }
    var rowFontSize: CGFloat { compactHeight ? 10 : 12 }
    var rowIndexFontSize: CGFloat { compactHeight ? 8 : 10 }
    var doneFontSize: CGFloat { compactHeight ? 11 : 13 }
    var searchIconSize: CGFloat { compactHeight ? 13 : 15 }
    var rowAccessorySize: CGFloat { compactHeight ? 13 : 15 }
}

private enum AlbumBookPalette {
    static let space = Color(red: 0.035, green: 0.145, blue: 0.18)
    static let deepPanel = Color(red: 0.035, green: 0.11, blue: 0.14)
    static let panel = Color(red: 0.055, green: 0.20, blue: 0.24)
    static let steel = Color(red: 0.34, green: 0.42, blue: 0.47)
    static let steelLight = Color(red: 0.63, green: 0.71, blue: 0.75)
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.015, green: 0.045, blue: 0.055)
    static let sky = Color(red: 0.20, green: 0.69, blue: 0.82)
    static let blueprint = Color(red: 0.05, green: 0.34, blue: 0.43)
    static let green = Color(red: 0.045, green: 0.31, blue: 0.24)
    static let greenBright = Color(red: 0.23, green: 0.76, blue: 0.55)
    static let crimson = Color(red: 0.48, green: 0.09, blue: 0.15)
}
