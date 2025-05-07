import SwiftUI
import CoreData

struct ChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var messageService: MessageService
    @StateObject private var voiceManager: AnyVoiceManager = AnyVoiceManager(VoiceManager())
    
    @State private var messageText = ""
    @State private var isRecording = false
    @State private var showRecordingError = false
    @FocusState private var isFocused: Bool
    @State private var isProcessing = false
    @State private var showScrollButton = false
    // MARK: – scroll‐tracking state
    @State private var scrollViewHeight: CGFloat = 0
    @State private var bottomAnchorY: CGFloat = 0

    private struct ScrollViewHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private struct BottomAnchorKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHistoryView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(Serenity.Colors.divider)
            
            ChatInputBar(
                text: $messageText,
                voiceManager: voiceManager,
                isProcessing: isProcessing
            ) { newMessage in
                isProcessing = true
                Task {
                    await messageService.sendMessage(newMessage)
                }
                isProcessing = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            guard voiceManager.isRecording else { return }
            messageText = newValue
        }
        .onTapGesture {
            isFocused = false
        }
        .alert("Voice Recording Error", isPresented: $showRecordingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to start voice recording. Please check permissions.")
        }
        .onAppear {
            messageService.updateAuthService(authService)
            messageService.refreshLastConversation()
        }
    }
    
    private var chatHistoryView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Serenity.Layout.smallPadding) {
                    ForEach(groupedMessages, id: \.0) { date, messages in
                        Section(header: dateHeader(for: date)) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding(.vertical, Serenity.Layout.standardPadding)
                Color.clear
                    .frame(height: 1)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: BottomAnchorKey.self,
                                    value: geo.frame(in: .named("chatScroll")).minY
                                )
                        }
                    )
            }
            .coordinateSpace(name: "chatScroll")
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollViewHeightKey.self,
                            value: geo.size.height
                        )
                }
            )
            // update our state whenever those two values change
            .onPreferenceChange(ScrollViewHeightKey.self) { scrollViewHeight = $0
            }
            .onPreferenceChange(BottomAnchorKey.self) { newY in
                bottomAnchorY = newY
                
                let bubblePadding = Serenity.Layout.standardPadding * 6
                    let threshold: CGFloat = bubblePadding
                    let shouldShow = bottomAnchorY > (scrollViewHeight + threshold)

                    // Animate the appearance/disappearance
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showScrollButton = shouldShow
                    }
            }
            .onAppear {
                DispatchQueue.main.async {
                    scrollToLastMessage(proxy: proxy)
                }
            }
            .onChange(of: messageService.messages.count) { _, _ in
                DispatchQueue.main.async {
                    scrollToLastMessage(proxy: proxy)
                }
            }
            .overlay(
                Group {
                    if showScrollButton {
                        Button {
                            withAnimation { scrollToLastMessage(proxy: proxy) }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 24))
                                .frame(width:        Serenity.Layout.minimumTapTarget,
                                   height: Serenity.Layout.minimumTapTarget)
                                .shadow(radius: 2)
                        }
                        .padding(Serenity.Layout.smallPadding)
                        .transition(
                            .move(edge: .bottom)
                            .combined(with: .opacity)
                        )
                    }
                }
                .zIndex(1),
                alignment: .bottom
            )
        }
    }
    
    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        if let lastMessage = messageService.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isProcessing = true
        messageText = ""
        
        Task {
            await messageService.sendMessage(trimmedText)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    // Update the groupedMessages computed p roperty
    private var groupedMessages: [(Date, [Message])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messageService.messages) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        // Change sorting order: oldest dates first (ascending)
        return grouped.sorted { $0.key < $1.key }
    }
    
    // Update the messages list in the ScrollView
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: Serenity.Layout.standardPadding) {
                ForEach(groupedMessages, id: \.0) { date, messages in
                    Section(header: dateHeader(for: date)) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
            }
            .padding(.vertical, Serenity.Layout.standardPadding)
        }
    }
    
    private func dateHeader(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isYesterday = Calendar.current.isDateInYesterday(date)
        
        let text = if isToday {
            "Today"
        } else if isYesterday {
            "Yesterday"
        } else {
            date.formatted(date: .abbreviated, time: .omitted)
        }
        
        return Text(text)
            .font(Serenity.Typography.caption())
            .foregroundColor(Serenity.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Serenity.Layout.smallPadding)
    }
}

// MARK: - Preview

#Preview {
    ChatView().withPreviewDependencies()
}

