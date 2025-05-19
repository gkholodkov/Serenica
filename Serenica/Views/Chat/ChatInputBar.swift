import SwiftUI
import Combine

struct ChatInputBar: View {
    @Binding var text: String
    @ObservedObject var voiceManager: AnyVoiceManager
    
    @State private var manuallyRequestFocus: Bool = false // manual trigger
    let isProcessing: Bool
    let sendAction: (String) -> Void
    var onFocusChange: ((Bool) -> Void)?
    
    // Track scroll position
    @State private var textViewHeight: CGFloat = 40 // base height
    @State private var lastSelection: UITextRange? = nil
    
    private let maxLines: Int = 3
    private let font: UIFont = .systemFont(ofSize: 17)

    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // Mic Button
            Button(action: toggleRecording) {
                Image(systemName: voiceManager.isRecording
                      ? "waveform.circle.fill"
                      : "waveform.circle")
                    .font(.system(size: 24))
                    .foregroundColor(voiceManager.isRecording ? Serenity.Colors.recordingOn : (isProcessing ? Serenity.Colors.secondary : Serenity.Colors.primary))
                    .frame(width: Serenity.Layout.minimumTapTarget,
                           height: Serenity.Layout.minimumTapTarget)
            }
            .disabled(isProcessing)
            
            // Input background tap area (to focus)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Please, type your message…")
                        .foregroundColor(Serenity.Colors.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                
                GrowingTextView(
                    text: $text,
                    focusTrigger: $manuallyRequestFocus,
                    maxLines: maxLines,
                    font: font,
                    height: $textViewHeight
                )
                .frame(height: textViewHeight)
                .disabled(voiceManager.isRecording)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                manuallyRequestFocus = true // request focus on tap
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Serenity.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Serenity.Layout.cornerRadius)
                    .stroke(manuallyRequestFocus ? Serenity.Colors.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            
            // Send Button
            Button(action: submit) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                    .rotationEffect(.degrees(45))
                    .foregroundColor(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing
                            ? Serenity.Colors.secondary
                            : Serenity.Colors.primary
                    )
                    .frame(width: Serenity.Layout.minimumTapTarget,
                            height: Serenity.Layout.minimumTapTarget)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
        .padding(.horizontal, Serenity.Layout.standardPadding)
        .padding(.vertical, Serenity.Layout.smallPadding)
        .background(Serenity.Colors.background)
        .onReceive(voiceManager.$transcribedText) { partial in
            if voiceManager.isRecording {
                text = partial
            }
        }
        .disabled(!voiceManager.isPermissionGranted)
        .onChange(of: manuallyRequestFocus) { _, newValue in
            onFocusChange?(newValue)
        }
    }
    
    private func toggleRecording() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
        } else {
            text = ""
            do {
                try voiceManager.startRecording()
            } catch {
                print("Recording failed:", error)
            }
        }
    }
    
    private func submit() {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        sendAction(msg)
        text = ""
        manuallyRequestFocus = true
    }
}
