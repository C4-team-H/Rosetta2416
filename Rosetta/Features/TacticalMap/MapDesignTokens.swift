import SwiftUI

enum MapDesignTokens {
    static let overlayAnimationDuration = 0.24
    static let contentSpacing: CGFloat = 12
    static let panelPadding: CGFloat = 16
    static let mapPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 32
    static let mapCornerRadius: CGFloat = 24

    // Chunky, illustrated console chrome inspired by social-deduction spaceship games.
    static let backdrop = Color(red: 0.018, green: 0.047, blue: 0.063)
    static let backdropLine = Color(red: 0.15, green: 0.43, blue: 0.47).opacity(0.12)
    static let ink = Color(red: 0.025, green: 0.075, blue: 0.09)
    static let panelShell = Color(red: 0.16, green: 0.31, blue: 0.34)
    static let panelShellHighlight = Color(red: 0.29, green: 0.49, blue: 0.51)
    static let panelInnerStroke = Color(red: 0.64, green: 0.83, blue: 0.81).opacity(0.34)
    static let panelWell = Color(red: 0.055, green: 0.14, blue: 0.16)
    static let rivet = Color(red: 0.52, green: 0.67, blue: 0.66)
    static let accent = Color(red: 0.35, green: 0.84, blue: 0.84)
    static let closeButton = Color(red: 0.89, green: 0.25, blue: 0.24)

    static let mapBezel = Color(red: 0.04, green: 0.13, blue: 0.15)
    static let mapBackground = Color(red: 0.055, green: 0.23, blue: 0.27)
    static let mapGrid = Color(red: 0.55, green: 0.9, blue: 0.86).opacity(0.12)
    static let mapGridMajor = Color(red: 0.58, green: 0.95, blue: 0.91).opacity(0.2)
    static let mapLabel = Color(red: 0.88, green: 1, blue: 0.96)
    static let mapLabelBackground = ink.opacity(0.76)

    static let hullFill = Color(red: 0.035, green: 0.13, blue: 0.15).opacity(0.76)
    static let hullStroke = Color(red: 0.46, green: 0.8, blue: 0.79).opacity(0.54)
    static let roomFill = Color(red: 0.25, green: 0.61, blue: 0.64).opacity(0.48)
    static let roomStroke = Color(red: 0.58, green: 0.94, blue: 0.9).opacity(0.88)
    static let corridorFill = Color(red: 0.15, green: 0.47, blue: 0.5).opacity(0.46)
    static let corridorStroke = Color(red: 0.43, green: 0.79, blue: 0.79).opacity(0.72)
    static let objectFill = Color(red: 0.1, green: 0.25, blue: 0.27).opacity(0.92)
    static let wall = Color(red: 0.025, green: 0.1, blue: 0.12).opacity(0.96)
    static let doorway = Color(red: 0.98, green: 0.74, blue: 0.24)

    static let activeMarker = Color(red: 1, green: 0.78, blue: 0.2)
    static let completedMarker = Color(red: 0.37, green: 0.76, blue: 0.42)
    static let unlockedMarker = accent
    static let lockedMarker = Color(red: 0.46, green: 0.54, blue: 0.55)
    static let blockedMarker = closeButton
    static let localCrew = Color(red: 0.24, green: 0.83, blue: 0.9)
    static let teammateCrew = Color(red: 0.96, green: 0.47, blue: 0.2)
    static let visor = Color(red: 0.67, green: 0.94, blue: 0.96)
}
