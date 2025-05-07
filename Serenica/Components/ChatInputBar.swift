import SwiftUI
import Combine

struct ChatInputBar: View {
    @Binding var text: String
    @ObservedObject var voiceManager: AnyVoiceManager
    @FocusState private var isFocused: Bool
    let isProcessing: Bool
    let sendAction: (String) -> Void

    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // MARK: – Mic / Stop button
            Button(action: toggleRecording) {
                Image(systemName: voiceManager.isRecording
                      ? "waveform.circle.fill"
                      : "waveform.circle")
                    .font(.system(size: 24))
                    .foregroundColor(voiceManager.isRecording ? .red : Serenity.Colors.primary)
                    .frame(width: Serenity.Layout.minimumTapTarget,
                           height: Serenity.Layout.minimumTapTarget)
            }

            // MARK: – Text Field
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Please, type your message…")
                        .foregroundColor(.secondary)
                }
                TextField("", text: $text)
                    .focused($isFocused)
                    .disabled(voiceManager.isRecording)
                    .onSubmit { submit() }
            }
            .padding(.vertical, Serenity.Layout.smallPadding)
            .padding(.horizontal, Serenity.Layout.standardPadding)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Serenity.Layout.cornerRadius)

            // MARK: – Send / Spinner
            if isProcessing {
                ProgressView()
                    .frame(width: Serenity.Layout.minimumTapTarget,
                           height: Serenity.Layout.minimumTapTarget)
            } else {
                Button(action: submit) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(45))
                        .foregroundColor(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .gray
                                : Serenity.Colors.primary
                        )
                        .frame(width: Serenity.Layout.minimumTapTarget,
                               height: Serenity.Layout.minimumTapTarget)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, Serenity.Layout.standardPadding)
        .padding(.vertical, Serenity.Layout.smallPadding)
        .background(Serenity.Colors.background)
        // keep the live transcription flowing into the field
        .onReceive(voiceManager.$transcribedText) { partial in
            if voiceManager.isRecording {
                text = partial
            }
        }
        .disabled(!voiceManager.isPermissionGranted)
    }

    private func toggleRecording() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
            // When the engine stops, the last transcription stays in `text`
        } else {
            text = ""
            do {
                try voiceManager.startRecording()
            } catch {
                // handle your error UI here, e.g. show an alert
                print("Recording failed to start:", error)
            }
        }
    }

    private func submit() {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        sendAction(msg)
        text = ""
        isFocused = true
    }
}
