import SwiftUI

/// Anchors the first-run tour can spotlight on the live Home / Plan UI.
enum WalkthroughAnchorID: Hashable {
    case safeToSpend
    case upcomingBills
    case addBill
}

struct WalkthroughAnchorKey: PreferenceKey {
    static var defaultValue: [WalkthroughAnchorID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [WalkthroughAnchorID: Anchor<CGRect>],
        nextValue: () -> [WalkthroughAnchorID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Reports this view’s bounds so the walkthrough can cut a spotlight hole.
    func walkthroughAnchor(_ id: WalkthroughAnchorID) -> some View {
        anchorPreference(key: WalkthroughAnchorKey.self, value: .bounds) { [id: $0] }
    }
}
