import Foundation
import CoreData


class AgentMemoryService: AgentMemoryServiceProtocol {
    private let memoryRepository: MemoryRepository
    private var chatShortTermMemory: [ChatMessage] = []
    private var toolsShortTermMemory: [ChatMessage] = []
    
    init(context: NSManagedObjectContext) {
        self.memoryRepository = MemoryRepository(context: context)
        // Ensure the memory exists for the current user.
        self.memoryRepository.createMemory()
    }
    
    func changeLongTermMemory(newEmotion: Emotion?, newFacts: [Fact]?, newPersonalityProfile: PersonalityProfile?) {
        // Fetch current memory from the repository.
        var memory = memoryRepository.fetchMemory()
        
        // Update the personality profile if a new one is provided.
        if let personality = newPersonalityProfile {
            memory.personality = personality
        }
        
        // Update the knowledge (facts) if provided.
        if let facts = newFacts {
            memory.knowledge = facts
        }
        
        // If a new emotion is provided, append it to the existing emotional state.
        if let emotion = newEmotion {
            memory.emotionalState.append(emotion)
        }
        
        // Update the stored memory.
        memoryRepository.updateMemory(memory)
    }
    
    func fetchLongTermMemory() -> String? {
        let memory = memoryRepository.fetchMemory()
        // Assuming Memory has a toString() method that summarizes its contents.
        return memory.toString()
    }
    
    func fetchLongTermMemoryEmotions() -> [Emotion] {
        let memory = memoryRepository.fetchMemory()
        return memory.emotionalState
    }
    
    func changeShortTermChatMemory(_ messages: [ChatMessage]) {
        for message in messages {
            chatShortTermMemory.append(message)
            if chatShortTermMemory.count > 15 {
                chatShortTermMemory.removeFirst()
            }
        }
    }
        
    func changeShortTermToolsMemory(_ messages: [ChatMessage]) {
        for message in messages {
            toolsShortTermMemory.append(message)
            if toolsShortTermMemory.count > 30 {
                toolsShortTermMemory.removeFirst()
            }
        }
    }
    
    func fetchShortTermChatMemory() -> [ChatMessage] {
        return chatShortTermMemory
    }
    
    func fetchShortTermToolsMemory() -> [ChatMessage] {
        return toolsShortTermMemory
    }
}
