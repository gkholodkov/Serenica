import SwiftUI

struct TypingIndicatorView: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text("is typing a message" + String(repeating: ".", count: dotCount))
            .font(Serenity.Typography.caption())
            .foregroundColor(Serenity.Colors.textSecondary)
            .padding(.horizontal, Serenity.Layout.standardPadding)
            .padding(.vertical, Serenity.Layout.smallPadding)
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
