import Foundation

struct EmotionRecognitionService {
    private let lexiconSentimentRecognitionService: LexiconSentimentRecognitionService
    private let llmService: AIServiceProtocol

    init(lexiconSentimentRecognitionService: LexiconSentimentRecognitionService = LexiconSentimentRecognitionService(), llmService: AIServiceProtocol) {
        self.lexiconSentimentRecognitionService = lexiconSentimentRecognitionService
        self.llmService = llmService
    }

    func analyzeEmotionHybrid(_ message: String, previousEmotion: Emotion?) async throws -> Emotion {
        // First, quick lexicon-based check
        let lexiconEmotion = lexiconSentimentRecognitionService.analyzePADEmotion(from: message)
        print("Lexicon emotion: \(lexiconEmotion)")

        // Check if lexicon-based change is significant
        let significantChange =
            previousEmotion != nil
            ? abs(lexiconEmotion.pleasure - previousEmotion!.pleasure) > 0.3 ||
              abs(lexiconEmotion.arousal - previousEmotion!.arousal) > 0.3 ||
              abs(lexiconEmotion.dominance - previousEmotion!.dominance) > 0.3
            : true

        if significantChange {
            // Delegate deeper analysis to GPT-4o-mini
            let response = try await llmService.getEmotionRecognitionResponse(message)
            return Emotion(pleasure: response.pleasure, arousal: response.arousal, dominance: response.dominance, label: EmotionLabel.from(response.label), timestamp: Date())
        } else {
            // As of now do the same, in the following maybe improve lexicon-based approach
            let response = try await llmService.getEmotionRecognitionResponse(message)
            return Emotion(pleasure: response.pleasure, arousal: response.arousal, dominance: response.dominance, label: EmotionLabel.from(response.label), timestamp: Date())
        }
    }

}
