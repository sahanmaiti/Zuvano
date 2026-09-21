import SwiftUI

enum ZuvanoTypography {
    static let screenHeadline = Font.title2
    static let screenSubheadline = Font.title3
    static let meta = Font.subheadline
    static let footnote = Font.footnote
    static let button = Font.body
}

extension View {
    func zuvanoScreenHeadlineStyle() -> some View {
        font(ZuvanoTypography.screenHeadline)
            .foregroundStyle(ZuvanoColors.primaryText)
            .multilineTextAlignment(.center)
    }

    func zuvanoContentHeadlineStyle() -> some View {
        font(ZuvanoTypography.screenHeadline)
            .foregroundStyle(ZuvanoColors.primaryText)
            .multilineTextAlignment(.leading)
    }

    func zuvanoMetaStyle() -> some View {
        font(ZuvanoTypography.meta)
            .foregroundStyle(ZuvanoColors.secondaryText)
            .multilineTextAlignment(.center)
    }

    func zuvanoLeadingMetaStyle() -> some View {
        font(ZuvanoTypography.meta)
            .foregroundStyle(ZuvanoColors.secondaryText)
            .multilineTextAlignment(.leading)
    }

    func zuvanoFootnoteStyle() -> some View {
        font(ZuvanoTypography.footnote)
            .foregroundStyle(ZuvanoColors.tertiaryText)
            .multilineTextAlignment(.center)
    }
}
