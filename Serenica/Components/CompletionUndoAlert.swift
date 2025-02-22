import SwiftUI

struct CompletionUndoAlert: View {
    let countdown: Int
    let cancelAction: () -> Void
    
    var body: some View {
        HStack {
            // Grouped components on the left: the question and the countdown.
            HStack(spacing: Serenity.Layout.smallPadding) {
                HStack(spacing: 4) {
                    Text("\(countdown)")
                        .font(Serenity.Typography.subtitle())
                    // A circular indicator showing the remaining time.
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 3.0)
                        .stroke(Serenity.Colors.secondary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: countdown)
                }
                Text("Task Completed!")
                    .font(Serenity.Typography.bodyText())
            }
            Spacer()
            // Cancel button on the right.
            Button(action: cancelAction) {
                Text("Cancel")
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.primary)
            }
        }
        .padding()
        .background(Serenity.Colors.background)
        .cornerRadius(10)
        .padding([.horizontal, .bottom])
        .shadow(radius: 2)
    }
}

#Preview {
    CompletionUndoAlert(countdown: 2) {}
}
