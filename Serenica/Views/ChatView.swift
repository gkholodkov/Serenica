import SwiftUI
import CoreData

struct ChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var messageService: MessageService
    @StateObject private var voiceManager = AnyVoiceManager(VoiceManager())
    
    @State private var messageText = ""
    @State private var scrollToBottomTrigger = false
    @State private var showScrollButton = false
    
    var body: some View {
        VStack(spacing: 0) {
            TypingNavTitleView(
                isTyping: messageService.isAgentTyping,
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .shadow(radius: 1)
            
            ChatHistoryView(
                messages: $messageService.messages,
                scrollToBottomTrigger: $scrollToBottomTrigger
            )
            .edgesIgnoringSafeArea(.all)

            Divider()
                .background(Serenity.Colors.divider)
            
            ChatInputBar(
                text: $messageText,
                voiceManager: voiceManager,
                isProcessing: messageService.isAgentTyping,
                sendAction: handleSendAction,
                onFocusChange: { isFocused in
                    // Optional: handle externally if needed
                    print("TextField focus changed:", isFocused)
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            messageService.updateAuthService(authService)
            messageService.refreshLastConversation()
            Task{ await messageService.startConversation() }
        }
    }
    
    private func handleSendAction(_ newMessage: String) {
        scrollToBottomTrigger = true
        Task {
            await messageService.sendMessage(newMessage)
            scrollToBottomTrigger = false
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview

#Preview {
    ChatView().withPreviewDependencies()
}

