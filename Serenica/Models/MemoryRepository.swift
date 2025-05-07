import CoreData
import SwiftUI

class MemoryRepository: MemoryRepositoryProtocol {
    private var context: NSManagedObjectContext
    private var authService: AuthService

    init(context: NSManagedObjectContext? = nil) {
        // Use provided context or fall back to the shared one.
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = AuthService(context: self.context)
    }
    
    // MARK: - Dependency Updates
    
    /// Call this to update the auth service (for example, when the user signs in or out).
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
    }
    
    /// If the current user does not have an associated memory, create one.
    func createMemory() {
        guard let userId = authService.currentUser?.id else { return }
        
        context.perform {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            guard let userEntity = try? self.context.fetch(userRequest).first else { return }
            
            // Only create if memory is currently nil.
            if userEntity.memory == nil {
                let memoryEntity = MemoryEntity(context: self.context)
                // Set empty relationships.
                memoryEntity.personality = nil
                memoryEntity.knowledge = NSSet()
                memoryEntity.emotionalState = NSSet()

                userEntity.memory = memoryEntity
                
                do {
                    try self.context.save()
                } catch {
                    print("Error creating memory: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Fetch the current user's memory by mapping the Core Data entities to the Swift model.
    func fetchMemory() -> Memory {
        guard let userId = authService.currentUser?.id else {
            fatalError("User not authenticated")
        }
        
        var memoryResult: Memory!
        
        // Use performAndWait because you need the result synchronously.
        context.performAndWait {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            guard let userEntity = try? context.fetch(userRequest).first,
                  let memoryEntity = userEntity.memory else {
                fatalError("Memory not found. Did you call createMemory()?")
            }
            
            // Map entities to your Memory model...
            var personalityProfile: PersonalityProfile? = nil
            if let personalityEntity = memoryEntity.personality,
               let mbtiRaw = personalityEntity.mbti,
               let mbti = MBTIType(rawValue: mbtiRaw) {
                let bigFive = BigFiveProfile(
                    openness: personalityEntity.bigFive_openness,
                    conscientiousness: personalityEntity.bigFive_conscientiousness,
                    extraversion: personalityEntity.bigFive_extraversion,
                    agreeableness: personalityEntity.bigFive_agreeableness,
                    neuroticism: personalityEntity.bigFive_neuroticism
                )
                let hexaco = HEXACOProfile(
                    honestyHumility: personalityEntity.hexaco_honestyHumility,
                    emotionality: personalityEntity.hexaco_emotionality,
                    extraversion: personalityEntity.hexaco_extraversion,
                    agreeableness: personalityEntity.hexaco_agreeableness,
                    conscientiousness: personalityEntity.hexaco_conscientiousness,
                    opennessToExperience: personalityEntity.hexaco_opennessToExperience
                )
                personalityProfile = PersonalityProfile(bigFive: bigFive, hexaco: hexaco, mbti: mbti)
            }
            
            // Map knowledge.
            var facts: [Fact] = []
            if let knowledgeSet = memoryEntity.knowledge as? Set<FactEntity> {
                facts = knowledgeSet.map { factEntity in
                    Fact(key: factEntity.key ?? "", value: factEntity.value ?? "", ttl: factEntity.ttl != nil ? Int(truncating: factEntity.ttl!) : nil, timestamp: factEntity.timestamp, importance: Int(factEntity.importance))
                }
            }
            
            // Map emotionalState.
            var emotions: [Emotion] = []
            if let emotionSet = memoryEntity.emotionalState as? Set<EmotionEntity> {
                emotions = emotionSet.map { emotionEntity in
                    let label: EmotionLabel? = emotionEntity.label.flatMap { EmotionLabel.from($0) }
                    return Emotion(pleasure: emotionEntity.pleasure,
                                   arousal: emotionEntity.arousal,
                                   dominance: emotionEntity.dominance,
                                   label: label,
                                   timestamp: emotionEntity.timestamp ?? Date(),
                                   consecutiveOccurrences: Int(emotionEntity.consecutiveOccurrences))
                }
            }
            
            // Compute today's emotion.
            let calendar = Calendar.current
            let todaysEmotions = emotions
                .filter { calendar.isDateInToday($0.timestamp) }
            var todaysEmotion = todaysEmotions
                .reduce(into: Emotion(pleasure: 0, arousal: 0, dominance: 0, timestamp: Date())) { result, emotion in
                    result.arousal += emotion.arousal / Double(todaysEmotions.count)
                    result.dominance += emotion.dominance / Double(todaysEmotions.count)
                    result.pleasure += emotion.pleasure / Double(todaysEmotions.count)
                }
            todaysEmotion.label = todaysEmotions.weightedModeLabel(timeDecayLambda: 0.4, intensityAlpha: 0.6)
            
            
            memoryResult = Memory(personality: personalityProfile,
                                  knowledge: facts,
                                  emotionalState: emotions,
                                  todaysEmotion: todaysEmotion)
        }
        
        return memoryResult
    }
    
    /// Update the current user's memory with the provided Memory model.
    func updateMemory(_ memory: Memory) {
        guard let userId = authService.currentUser?.id else { return }
        
        context.perform {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            if let userEntity = try? self.context.fetch(userRequest).first,
               let memoryEntity = userEntity.memory {
                // Update personality as before.
                if let personality = memory.personality {
                    let personalityEntity: PersonalityProfileEntity
                    if let existing = memoryEntity.personality {
                        personalityEntity = existing
                    } else {
                        personalityEntity = PersonalityProfileEntity(context: self.context)
                        memoryEntity.personality = personalityEntity
                    }
                    personalityEntity.mbti = personality.mbti.rawValue
                    personalityEntity.bigFive_openness = personality.bigFive.openness
                    personalityEntity.bigFive_conscientiousness = personality.bigFive.conscientiousness
                    personalityEntity.bigFive_extraversion = personality.bigFive.extraversion
                    personalityEntity.bigFive_agreeableness = personality.bigFive.agreeableness
                    personalityEntity.bigFive_neuroticism = personality.bigFive.neuroticism
                    
                    personalityEntity.hexaco_opennessToExperience = personality.hexaco.opennessToExperience
                    personalityEntity.hexaco_honestyHumility = personality.hexaco.honestyHumility
                    personalityEntity.hexaco_extraversion = personality.hexaco.extraversion
                    personalityEntity.hexaco_emotionality = personality.hexaco.emotionality
                    personalityEntity.hexaco_conscientiousness = personality.hexaco.conscientiousness
                    personalityEntity.hexaco_agreeableness = personality.hexaco.agreeableness
                } else {
                    if let personalityEntity = memoryEntity.personality {
                        self.context.delete(personalityEntity)
                        memoryEntity.personality = nil
                    }
                }
                
                // Update knowledge.
                if let existingFacts = memoryEntity.knowledge as? Set<FactEntity> {
                    for factEntity in Array(existingFacts) {
                        self.context.delete(factEntity)
                    }
                }
                var newFacts = Set<FactEntity>()
                for fact in memory.knowledge {
                    let factEntity = FactEntity(context: self.context)
                    factEntity.key = fact.key
                    factEntity.value = fact.value
                    factEntity.ttl = fact.ttl != nil ? Int32(fact.ttl!) as NSNumber? : nil
                    factEntity.timestamp = fact.timestamp
                    factEntity.importance = Int16(fact.importance)
                    newFacts.insert(factEntity)
                }
                memoryEntity.knowledge = newFacts as NSSet
                
                // Update emotionalState.
                if let existingEmotions = memoryEntity.emotionalState as? Set<EmotionEntity> {
                    for emotionEntity in Array(existingEmotions) {
                        self.context.delete(emotionEntity)
                    }
                }
                var newEmotions = Set<EmotionEntity>()
                for emotion in memory.emotionalState {
                    let emotionEntity = EmotionEntity(context: self.context)
                    emotionEntity.pleasure = emotion.pleasure
                    emotionEntity.arousal = emotion.arousal
                    emotionEntity.dominance = emotion.dominance
                    emotionEntity.label = emotion.label?.rawValue
                    emotionEntity.timestamp = emotion.timestamp
                    newEmotions.insert(emotionEntity)
                }
                memoryEntity.emotionalState = newEmotions as NSSet
                
                do {
                    try self.context.save()
                } catch {
                    print("Error updating memory: \(error.localizedDescription)")
                }
            }
        }
    }

    
    /// Remove the memory from the current user.
    func clearMemory() {
        guard let userId = authService.currentUser?.id else { return }
        
        context.perform {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            if let userEntity = try? self.context.fetch(userRequest).first {
                if let memoryEntity = userEntity.memory {
                    // Optionally delete the MemoryEntity from context.
                    self.context.delete(memoryEntity)
                }
                
                let newMem = MemoryEntity(context: self.context)
                newMem.personality = nil
                newMem.knowledge = []
                newMem.emotionalState = []
                
                userEntity.memory = newMem
                
                do {
                    try self.context.save()
                } catch {
                    print("Error clearing memory: \(error.localizedDescription)")
                }
            }
        }
    }
}

