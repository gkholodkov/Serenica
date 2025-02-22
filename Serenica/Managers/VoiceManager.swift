import Speech
import AVFoundation

class VoiceManager: NSObject, VoiceManaging {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isPermissionGranted = false
    @Published var isTranscriptionFinished = false
    private var currentTranscription = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let synthesizer = AVSpeechSynthesizer()
    private let isPreview: Bool
    
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        super.init()
        
        if !isPreview {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isPermissionGranted = status == .authorized
            }
        }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = self?.isPermissionGranted ?? false && granted
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = self?.isPermissionGranted ?? false && granted
                }
            }
        }
    }
    
    func startRecording() throws {
        guard !isPreview else { return }
        
        resetAudio()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: audioSession.sampleRate,
                                          channels: 1)
        guard let format = recordingFormat else {
            throw NSError(domain: "VoiceManager", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Could not create audio format"])
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            if error != nil {
                self.stopRecording()
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }
    
    func stopRecording() {
        guard !isPreview else { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    func speakText(_ text: String) {
        guard !isPreview else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    private func resetAudio() {
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        transcribedText = ""
        isTranscriptionFinished = false
    }
} 
