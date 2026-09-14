import SwiftUI

enum PennySpacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 6
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40

    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 24

    static let radiusSm: CGFloat = 12
    static let radiusMd: CGFloat = 16
    static let radiusLg: CGFloat = 20
    static let radiusXl: CGFloat = 24
    static let radiusPill: CGFloat = 100

    static let minTapTarget: CGFloat = 44
}

enum PennyAnimation {
    static let quick: Animation = .easeInOut(duration: 0.2)
    static let standard: Animation = .easeInOut(duration: 0.28)
    static let emphasis: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    static func prefer(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
