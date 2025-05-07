import Foundation
import Speech
import AVFoundation
import Combine

/// A simple, standalone manager you can wrap in `AnyVoiceManager`.
final class VoiceManager: NSObject, VoiceManaging {
  // MARK: Published state
  @Published var isRecording = false
  @Published var transcribedText = ""
  @Published var isPermissionGranted = false
  @Published var isTranscriptionFinished = false

  // MARK: Private speech/AV props
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let speechRecognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
  private let synthesizer = AVSpeechSynthesizer()

  override init() {
    super.init()
    requestPermissions()
  }

  private func requestPermissions() {
    // Speech
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        self.isPermissionGranted = (status == .authorized)
      }
    }
    // Microphone
    AVAudioApplication.requestRecordPermission { granted in
        DispatchQueue.main.async {
            // only true if both speech & mic are granted
            self.isPermissionGranted = self.isPermissionGranted && granted
        }
    }
  }

  func startRecording() throws {
    guard isPermissionGranted else {
      throw RecordingError.permissionDenied
    }
    // If already running, toggle off
    if audioEngine.isRunning {
      stopRecording()
      return
    }

    // Prepare speech request
    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true
    recognitionRequest = req

    // Kick off the recognition task
    recognitionTask = speechRecognizer?
      .recognitionTask(with: req) { [weak self] result, error in
        guard let self = self else { return }

        if let result = result {
          // update partial/final text
          DispatchQueue.main.async {
            self.transcribedText = result.bestTranscription.formattedString
          }
          if result.isFinal {
            self.finishRecording()
          }
        }
        else if error != nil {
          self.finishRecording()
        }
      }

    // Configure audio session
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    // Route mic input into the recognition request
    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(
      onBus: 0,
      bufferSize: 1_024,
      format: format
    ) { buffer, _ in
      req.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()

    DispatchQueue.main.async {
      self.isRecording = true
      self.isTranscriptionFinished = false
    }
  }

  func stopRecording() {
    guard audioEngine.isRunning else { return }
    audioEngine.stop()
    recognitionRequest?.endAudio()
    finishRecording()
  }

  private func finishRecording() {
    // tear down
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil

    DispatchQueue.main.async {
      self.isRecording = false
      self.isTranscriptionFinished = true
    }
  }

  func speakText(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.5
    synthesizer.speak(utterance)
  }

  enum RecordingError: LocalizedError {
    case permissionDenied
    var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return "Microphone or Speech recognition permission was not granted."
      }
    }
  }
}

