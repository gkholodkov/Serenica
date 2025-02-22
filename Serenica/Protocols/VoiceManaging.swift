import SwiftUI
import Combine

protocol VoiceManaging: ObservableObject {
    var isRecording: Bool { get set }
    var transcribedText: String { get set }
    var isPermissionGranted: Bool { get set }
    var isTranscriptionFinished: Bool { get set }
    
    func startRecording() throws
    func stopRecording()
    func speakText(_ text: String)
}

// Extension to provide default implementations for published properties
extension VoiceManaging {
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        objectWillChange
            .compactMap { [weak self] _ in self?.isRecording }
            .prepend(isRecording)
            .eraseToAnyPublisher()
    }
    
    var transcribedTextPublisher: AnyPublisher<String, Never> {
        objectWillChange
            .compactMap { [weak self] _ in self?.transcribedText }
            .prepend(transcribedText)
            .eraseToAnyPublisher()
    }
    
    var isPermissionGrantedPublisher: AnyPublisher<Bool, Never> {
        objectWillChange
            .compactMap { [weak self] _ in self?.isPermissionGranted }
            .prepend(isPermissionGranted)
            .eraseToAnyPublisher()
    }
    
    var isTranscriptionFinishedPublisher: AnyPublisher<Bool, Never> {
        objectWillChange
            .compactMap { [weak self] _ in self?.isTranscriptionFinished }
            .prepend(isTranscriptionFinished)
            .eraseToAnyPublisher()
    }
} 
