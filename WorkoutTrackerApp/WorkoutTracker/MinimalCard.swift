import SwiftUI

extension View {
    /// White surface + hairline border + very soft shadow (minimal / editorial).
    func minimalCard(cornerRadius: CGFloat? = nil) -> some View {
        let r = cornerRadius ?? AppTheme.cardCornerRadius
        return self
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.cardShadow,
                radius: AppTheme.cardShadowRadius,
                x: 0,
                y: AppTheme.cardShadowY
            )
    }
}
