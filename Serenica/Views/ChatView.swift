//
//  ChatView.swift
//  Serenica
//
//  Created by Checkito12 on 17.01.25.
//


import SwiftUI
import CoreData

/// ChatView
///
/// Key points based on your clarifications:
/// 1. We *do* persist messages using CoreData, but the code below just shows the in-memory aspect.
///    (We could add CoreData save logic in `MessageStore` or wherever appropriate.)
/// 2. messageStore is in-memory now and we only need to send messages (no extra logging).
/// 3. voiceManager has properties: isRecording, transcribedText, isPermissionGranted, isTranscriptionFinished,
///    plus startRecording(), stopRecording(), and speakText().
/// 4. We always send the voice-transcribed text *immediately* once recording stops (2nd click).
/// 5. The TextField is disabled during recording.
/// 6. We only speak messages aloud when the user taps a message bubble; no automatic TTS for now.
/// 7. Starting to record clears whatever was in the text field.

struct ChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @StateObject private var messageStore: MessageStore
    @StateObject private var voiceManager: AnyVoiceManager
    
    @State private var messageText = ""
    @State private var isRecording = false
    @State private var showRecordingError = false
    @FocusState private var isFocused: Bool
    @State private var isProcessing = false
    
    init() {
        let voiceManager = VoiceManager()
        _voiceManager = StateObject(wrappedValue: AnyVoiceManager(voiceManager))
        _messageStore = StateObject(wrappedValue: MessageStore())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatHistoryView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(Serenity.Colors.divider)
            
            inputSection
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
            messageStore.updateAuthService(authService)
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
            }
            .onChange(of: messageStore.messages.count) { _, _ in
                scrollToLastMessage(proxy: proxy)
            }
        }
    }
    
    private var inputSection: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // Voice recording button
            Button(action: toggleRecording) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isRecording ? .red : Serenity.Colors.primary)
                    .frame(width: Serenity.Layout.minimumTapTarget, 
                           height: Serenity.Layout.minimumTapTarget)
            }
            
            // Text input field
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .disabled(isRecording)
            
            // Send button
            if isProcessing {
                ProgressView()
                    .frame(width: Serenity.Layout.minimumTapTarget, 
                           height: Serenity.Layout.minimumTapTarget)
            } else {
                Button(action: { sendMessage(messageText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Serenity.Colors.primary)
                        .frame(width: Serenity.Layout.minimumTapTarget, 
                               height: Serenity.Layout.minimumTapTarget)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, Serenity.Layout.standardPadding)
        .padding(.vertical, Serenity.Layout.smallPadding)
    }
    
    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        if let lastMessage = messageStore.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            voiceManager.stopRecording()
            isRecording = false
            if !voiceManager.transcribedText.isEmpty {
                sendMessage(voiceManager.transcribedText)
                voiceManager.transcribedText = ""
            }
        } else {
            messageText = ""
            do {
                try voiceManager.startRecording()
                isRecording = true
            } catch {
                showRecordingError = true
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isProcessing = true
        messageText = ""
        
        Task {
            do {
                try await messageStore.sendMessage(trimmedText)
            } catch {
                // Handle error if needed
                print("Error sending message: \(error.localizedDescription)")
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    // Update the groupedMessages computed property
    private var groupedMessages: [(Date, [Message])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messageStore.messages) { message in
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
