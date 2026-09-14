import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Keyboard {
    /// Resignes the current first responder so decimal pads dismiss after Save.
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

extension View {
    /// Adds a keyboard accessory "Done" button that dismisses the decimal pad.
    func pennyKeyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    Keyboard.dismiss()
                }
            }
        }
    }
}
