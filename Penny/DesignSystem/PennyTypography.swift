import SwiftUI

/// Typography scale for Penny. Numbers use monospaced digits where scanability matters.
enum PennyTypography {
    /// Large balance / safe-to-spend hero (34–44pt)
    static let heroAmount = Font.system(size: 40, weight: .bold, design: .rounded)
    static let largeAmount = Font.system(size: 34, weight: .bold, design: .rounded)
    static let mediumAmount = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let smallAmount = Font.system(size: 17, weight: .semibold, design: .rounded)

    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let sectionHeading = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .default)

    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyEmphasized = Font.system(size: 16, weight: .medium, design: .default)
    static let callout = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .medium, design: .default)
    static let footnote = Font.system(size: 12, weight: .regular, design: .default)
    static let overline = Font.system(size: 12, weight: .semibold, design: .default)
}

extension View {
    func pennyMoneyFont(_ font: Font = PennyTypography.mediumAmount) -> some View {
        self.font(font).monospacedDigit()
    }
}
