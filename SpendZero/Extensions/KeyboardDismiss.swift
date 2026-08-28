import SwiftUI

extension View {
    /// Standard keyboard behaviour for entry sheets: drag to tuck the keyboard away and a
    /// Done button above the keyboard.
    func dismissableKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                    .font(AppTheme.bodyFont.weight(.semibold))
                }
            }
    }
}
