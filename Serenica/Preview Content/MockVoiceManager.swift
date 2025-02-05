//
//  MockVoiceManager.swift
//  Serenica
//
//  Created by Checkito12 on 19.12.24.
//


import SwiftUI

class MockVoiceManager: VoiceManaging {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isPermissionGranted = true
    @Published var isTranscriptionFinished = false
    private var mockTranscription = ""
    
    func startRecording() throws {
        isRecording = true
        isTranscriptionFinished = false
        transcribedText = ""
        
        // Simulate ongoing transcription
        mockTranscription = "Mock transcription"
    }
    
    func stopRecording() {
        isRecording = false
        // Only set the final transcription when stopping
        if !mockTranscription.isEmpty {
            transcribedText = mockTranscription
            isTranscriptionFinished = true
        }
    }
    
    func speakText(_ text: String) {
        print("Preview Mode - Speaking: \(text)")
    }
} 
