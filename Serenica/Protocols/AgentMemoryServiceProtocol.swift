import Foundation

protocol AgentMemoryServiceProtocol {
    func changeLongTermMemory(newEmotion: Emotion?, newFacts: [Fact]?, newPersonalityProfile: PersonalityProfile?)
    func fetchLongTermMemory() -> String?
    func fetchLongTermMemoryEmotions() -> [Emotion]
    func changeShortTermChatMemory(_ messages: [ChatMessage])
    func changeShortTermToolsMemory(_ messages: [ChatMessage])
    func fetchShortTermChatMemory() -> [ChatMessage]
    func fetchShortTermToolsMemory() -> [ChatMessage]
}
