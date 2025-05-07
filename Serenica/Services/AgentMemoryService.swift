import Foundation
import CoreData


class AgentMemoryService {
    private let memoryRepository: MemoryRepository
    private var chatShortTermMemory: [ChatMessage] = []
    private var toolsShortTermMemory: [ChatMessage] = []
    
    // Serial queue to synchronize access to in‑memory collections.
    private let memoryQueue = DispatchQueue(label: "com.myapp.agentMemoryQueue")
    
    init(context: NSManagedObjectContext) {
        self.memoryRepository = MemoryRepository(context: context)
        // Ensure the memory exists for the current user.
        memoryRepository.createMemory()
    }
    
    // MARK: - Dependency Updates
    
    /// Call this to update the auth service (for example, when the user signs in or out).
    func updateAuthService(_ newAuthService: AuthService) {
        memoryRepository.updateAuthService(newAuthService)
        memoryRepository.createMemory()
    }
        
    func changeLongTermMemory(newEmotion: Emotion?, newFacts: [Fact]?, newPersonalityProfile: PersonalityProfile?) async {
        // Fetch current memory from the repository.
        var memory = memoryRepository.fetchMemory()
        
        // Update the personality profile if a new one is provided.
        if let personality = newPersonalityProfile {
            memory.personality = personality
        }
        
        // Update the knowledge (facts) if provided.
        if let facts = newFacts {
            memory.knowledge = processNewFacts(existing: memory.knowledge, adding: facts)
        }
            
        // If a new emotion is provided, append it to the existing emotional state.
        if let emotion = newEmotion {
            if let origEmotion = memory.emotionalState.last, origEmotion == emotion {
                var finalEmotion = origEmotion
                finalEmotion.consecutiveOccurrences += 1
                memory.emotionalState[memory.emotionalState.count - 1] = finalEmotion
            }
            else {
                memory.emotionalState.append(emotion)
            }
        }
            
        // Update the stored memory.
        memoryRepository.updateMemory(memory)
    }
    
    func fetchLongTermMemoryDescription() -> String? {
        let memory = memoryRepository.fetchMemory()
        // Assuming Memory has a toString() method that summarizes its contents.
        return memory.toString()
    }
        
    func fetchLongTermMemory() -> Memory {
        return memoryRepository.fetchMemory()
    }
        
    func changeShortTermMemory(_ messages: [ChatMessage]) {
        memoryQueue.sync {
            // Append only messages that are not tool responses.
            let filteredMessages = messages.filter { $0.role != .tool && !($0.role == .assistant && $0.tool_calls != nil) }
            self.chatShortTermMemory.append(contentsOf: filteredMessages)
            self.toolsShortTermMemory.append(contentsOf: messages)
                
            // Keep chatShortTermMemory to a maximum of 16 elements.
            if self.chatShortTermMemory.count > 16 {
                self.chatShortTermMemory.removeFirst(self.chatShortTermMemory.count - 16)
            }
            // Keep toolsShortTermMemory to a maximum of 30 elements.
            if self.toolsShortTermMemory.count > 20 {
                self.toolsShortTermMemory.removeFirst(self.toolsShortTermMemory.count - 20)
                if self.toolsShortTermMemory.first?.role == .tool {
                    self.toolsShortTermMemory.removeFirst()
                }
            }
        }
    }
        
        
    func fetchShortTermChatMemory() -> [ChatMessage] {
        return memoryQueue.sync {
            return self.chatShortTermMemory
        }
    }
        
    func fetchShortTermToolsMemory() -> [ChatMessage] {
        return memoryQueue.sync {
            return self.toolsShortTermMemory
        }
    }
        
    func clearMemory() {
        memoryRepository.clearMemory()
        chatShortTermMemory.removeAll()
        toolsShortTermMemory.removeAll()
    }
    
    private func processNewFacts(existing: [Fact], adding newFacts: [Fact]?) -> [Fact] {
        let now = Date()
        // 1. Combine
        let combined = existing + (newFacts ?? [])
            
        // 2. Filter out any that have expired (timestamp + ttl days ≤ now)
        let alive = combined.filter { fact in
            guard let ttl = fact.ttl, let ts = fact.timestamp else {
                // no ttl → unbounded
                return true
            }
            let expiry = ts.addingTimeInterval(TimeInterval(ttl * 24 * 3600))
            return expiry > now
        }
        
        // 3. Dedupe by key, merging values
        var byKey: [String: Fact] = [:]
        for fact in alive {
            if let existing = byKey[fact.key] {
                let mergedValue = existing.value + "; " + fact.value
                // carry forward the longer‐running TTL if both exist
                let mergedTTL = existing.ttl == nil || fact.ttl == nil ? nil : [existing.ttl, fact.ttl].compactMap { $0 }.max()
                let mergedTs = existing.timestamp ?? fact.timestamp
                let mergedImportance = [existing.importance, fact.importance].max() ?? existing.importance
                
                byKey[fact.key] = Fact(key: fact.key,
                                        value: mergedValue,
                                        ttl: mergedTTL,
                                        timestamp: mergedTs,
                                       importance: mergedImportance)
            } else {
                byKey[fact.key] = fact
            }
        }
            
        // 4. Sort by TTL ascending (nil TTL pushed to the end), then trim to most important 50
        let allFacts = Array(byKey.values)
        let withTTL = allFacts.filter { $0.ttl != nil }
            .sorted { $0.ttl! < $1.ttl! }
        let withoutTTL = allFacts.filter { $0.ttl == nil }
        let sorted = Array(withTTL.suffix(50)) + withoutTTL
            
        return sorted
    }
}

