import Foundation

struct FactExtractionService {
    private let llmService: AIServiceProtocol

    /// Initialize with an instance of your AI service.
    init(llmService: AIServiceProtocol) {
        self.llmService = llmService
    }
    
    func extractNewFacts(_ messages: [ChatMessage], knownFacts: [String]) async -> [Fact] {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else {
            print("No user message found.")
            return []
        }
        
        do {
            // Example: Exclude the last user message and any assistant responses
            let history = messages.prefix(while: { $0 != lastUserMessage })
            let response = try await llmService.getFactExtractionResponse(
                lastUserMessage.content,
                factContext: knownFacts,
                messageHistory: Array(history)
            )
            
            return response
        } catch {
            print("Error processing message for fact extraction: \(error)")
            return []
        }
    }
}
