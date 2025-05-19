import SwiftUI

struct TypingNavTitleView: View {
    let isTyping: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("Serenica")
                .font(.headline)
            if isTyping {
                TypingIndicatorView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isTyping)
    }
}
