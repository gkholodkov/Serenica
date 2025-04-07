import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Serenity.Layout.standardPadding) {
            if message.isFromUser { 
                Spacer(minLength: Serenity.Layout.minimumTapTarget) 
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: Serenity.Layout.tinyPadding) {
                Text(message.content)
                    .font(Serenity.Typography.messageText())
                    .lineSpacing(4)
                    .padding(.horizontal, Serenity.Layout.standardPadding)
                    .padding(.vertical, Serenity.Layout.smallPadding)
                    .background(
                        message.isFromUser ? 
                            Serenity.Colors.messageBubbleUser : 
                            Serenity.Colors.messageBubbleBot
                    )
                    .foregroundColor(Serenity.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Serenity.Layout.messageBubbleRadius))
                
                Text(message.timeString)
                    .font(Serenity.Typography.caption())
                    .foregroundColor(Serenity.Colors.textSecondary)
                    .padding(.horizontal, Serenity.Layout.tinyPadding)
            }
            
            if !message.isFromUser { 
                Spacer(minLength: Serenity.Layout.minimumTapTarget) 
            }
        }
        .padding(.horizontal, Serenity.Layout.smallPadding)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(message: Message(
            content: "Hello! How can I help you today?",
            isFromUser: false
        ))
        MessageBubble(message: Message(
            content: "I need help with SwiftUI",
            isFromUser: true
        ))
    }
    .padding()
} 
