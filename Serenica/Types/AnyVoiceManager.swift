import SwiftUI
import Combine

final class AnyVoiceManager: ObservableObject {
    @Published var isRecording: Bool
    @Published var transcribedText: String
    @Published var isPermissionGranted: Bool
    @Published var isTranscriptionFinished: Bool
    
    private let startRecordingClosure: () throws -> Void
    private let stopRecordingClosure: () -> Void
    private let speakTextClosure: (String) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    init<T: VoiceManaging>(_ manager: T) {
        // Initialize properties first
        self.isRecording = manager.isRecording
        self.transcribedText = manager.transcribedText
        self.isPermissionGranted = manager.isPermissionGranted
        self.isTranscriptionFinished = manager.isTranscriptionFinished
        self.startRecordingClosure = manager.startRecording
        self.stopRecordingClosure = manager.stopRecording
        self.speakTextClosure = manager.speakText
        
        // Set up publishers
        manager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        manager.isRecordingPublisher
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        manager.transcribedTextPublisher
            .assign(to: \.transcribedText, on: self)
            .store(in: &cancellables)
        
        manager.isPermissionGrantedPublisher
            .assign(to: \.isPermissionGranted, on: self)
            .store(in: &cancellables)
        
        manager.isTranscriptionFinishedPublisher
            .assign(to: \.isTranscriptionFinished, on: self)
            .store(in: &cancellables)
    }
    
    func startRecording() throws {
        try startRecordingClosure()
    }
    
    func stopRecording() {
        stopRecordingClosure()
    }
    
    func speakText(_ text: String) {
        speakTextClosure(text)
    }
} 
