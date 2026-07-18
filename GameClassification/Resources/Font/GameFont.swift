//
//  GameFont.swift
//  GameClassification
//
//  Created by Muhammad Muthi' Nuritzan on 16/07/26.
//

import UIKit
import CoreText
import SwiftUI

enum GameFont {

    struct Token {
        let fontName: String
        let fontSize: CGFloat
        let fontWeight: CGFloat
        let letterSpacing: CGFloat
        let lineHeightMultiple: CGFloat

        var font: Font {
            let variations: [Int: CGFloat] = [
                GameFont.weightAxisIdentifier: fontWeight,
                GameFont.widthAxisIdentifier: GameFont.defaultWidth
            ]

            let descriptor = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: fontName as CFString,
                kCTFontVariationAttribute: variations as CFDictionary
            ] as CFDictionary)

            let ctFont = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)

            return Font(ctFont)
        }

        var uiFont: UIFont {
            let variations: [Int: CGFloat] = [
                GameFont.weightAxisIdentifier: fontWeight,
                GameFont.widthAxisIdentifier: GameFont.defaultWidth
            ]

            let descriptor = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: fontName as CFString,
                kCTFontVariationAttribute: variations as CFDictionary
            ] as CFDictionary)

            let ctFont = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
            return ctFont as UIFont
        }

        var lineHeight: CGFloat {
            fontSize * lineHeightMultiple
        }

        var lineSpacing: CGFloat {
            max(0, lineHeight - fontSize)
        }
    }

    // MARK: - Font Configuration

    static let fontName = "MuseoModerno"

    private static let defaultWidth: CGFloat = 100

    /// "wght"
    static let weightAxisIdentifier = 2_003_265_652

    /// "wdth"
    static let widthAxisIdentifier = 2_003_072_104

    // MARK: - Large Title

    static let largeTitle = token(
        fontSize: 34,
        fontWeight: 400,
        lineHeightMultiple: 1.2058823529411764
    )

    static let largeTitleBold = token(
        fontSize: 34,
        fontWeight: 700,
        lineHeightMultiple: 1.2058823529411764
    )

    // MARK: - Title 1

    static let title1 = token(
        fontSize: 28,
        fontWeight: 400,
        lineHeightMultiple: 1.2142857142857142
    )

    static let title1Bold = token(
        fontSize: 28,
        fontWeight: 700,
        lineHeightMultiple: 1.2142857142857142
    )

    // MARK: - Title 2

    static let title2 = token(
        fontSize: 22,
        fontWeight: 400,
        lineHeightMultiple: 1.2727272727272727
    )

    static let title2Bold = token(
        fontSize: 22,
        fontWeight: 700,
        lineHeightMultiple: 1.2727272727272727
    )

    // MARK: - Title 3

    static let title3 = token(
        fontSize: 20,
        fontWeight: 400,
        lineHeightMultiple: 1.25
    )

    static let title3Bold = token(
        fontSize: 20,
        fontWeight: 600,
        lineHeightMultiple: 1.25
    )

    // MARK: - Headline

    static let headline = token(
        fontSize: 17,
        fontWeight: 600,
        lineHeightMultiple: 1.2941176470588236
    )

    static let headlineBold = token(
        fontSize: 17,
        fontWeight: 700,
        lineHeightMultiple: 1.2941176470588236
    )

    // MARK: - Body

    static let body = token(
        fontSize: 17,
        fontWeight: 400,
        lineHeightMultiple: 1.2941176470588236
    )

    static let bodyMedium = token(
        fontSize: 17,
        fontWeight: 500,
        lineHeightMultiple: 1.2941176470588236
    )

    static let bodySemiBold = token(
        fontSize: 17,
        fontWeight: 600,
        lineHeightMultiple: 1.2941176470588236
    )

    static let bodyBold = token(
        fontSize: 17,
        fontWeight: 700,
        lineHeightMultiple: 1.2941176470588236
    )

    // MARK: - Callout

    static let callout = token(
        fontSize: 16,
        fontWeight: 400,
        lineHeightMultiple: 1.3125
    )

    static let calloutBold = token(
        fontSize: 16,
        fontWeight: 600,
        lineHeightMultiple: 1.3125
    )

    // MARK: - Subhead

    static let subhead = token(
        fontSize: 15,
        fontWeight: 400,
        lineHeightMultiple: 1.3333333333333333
    )

    static let subheadBold = token(
        fontSize: 15,
        fontWeight: 600,
        lineHeightMultiple: 1.3333333333333333
    )

    static let subheadline = subhead
    static let subheadlineBold = subheadBold

    // MARK: - Footnote

    static let footnote = token(
        fontSize: 13,
        fontWeight: 400,
        lineHeightMultiple: 1.3846153846153846
    )

    static let footnoteBold = token(
        fontSize: 13,
        fontWeight: 600,
        lineHeightMultiple: 1.3846153846153846
    )

    // MARK: - Caption 1

    static let caption1 = token(
        fontSize: 12,
        fontWeight: 400,
        lineHeightMultiple: 1.3333333333333333
    )

    static let caption1Bold = token(
        fontSize: 12,
        fontWeight: 600,
        lineHeightMultiple: 1.3333333333333333
    )

    // MARK: - Caption 2

    static let caption2 = token(
        fontSize: 11,
        fontWeight: 400,
        lineHeightMultiple: 1.1818181818181819
    )

    static let caption2Bold = token(
        fontSize: 11,
        fontWeight: 600,
        lineHeightMultiple: 1.1818181818181819
    )

    // MARK: - Factory

    static func custom(size: CGFloat, weight: CGFloat = 400) -> Token {
        token(fontSize: size, fontWeight: weight, lineHeightMultiple: 1.2)
    }

    private static func token(
        fontSize: CGFloat,
        fontWeight: CGFloat,
        lineHeightMultiple: CGFloat
    ) -> Token {
        Token(
            fontName: fontName,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: 0,
            lineHeightMultiple: lineHeightMultiple
        )
    }
}

extension View {

    func font(_ appFont: GameFont.Token) -> some View {
        self.font(appFont.font)
    }
}
