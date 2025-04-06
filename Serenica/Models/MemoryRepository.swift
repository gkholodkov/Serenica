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
    
    /// If the current user does not have an associated memory, create one.
    func createMemory() {
        guard let userId = authService.currentUser?.id else { return }
        
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        
        guard let userEntity = try? context.fetch(userRequest).first else { return }
        
        // Only create if memory is currently nil.
        if userEntity.memory == nil {
            let memoryEntity = MemoryEntity(context: context)
            // Set empty relationships.
            memoryEntity.personality = nil
            memoryEntity.knowledge = NSSet()
            memoryEntity.emotionalState = NSSet()
            
            userEntity.memory = memoryEntity
            
            do {
                try context.save()
            } catch {
                print("Error creating memory: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetch the current user's memory by mapping the Core Data entities to the Swift model.
    func fetchMemory() -> Memory {
        guard let userId = authService.currentUser?.id else {
            fatalError("User not authenticated")
        }
        
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        
        guard let userEntity = try? context.fetch(userRequest).first,
              let memoryEntity = userEntity.memory else {
            fatalError("Memory not found. Did you call createMemory()?")
        }
        
        // Map PersonalityProfileEntity to PersonalityProfile (if available).
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
        
        // Map knowledge: Convert FactEntity set to [Fact].
        var facts: [Fact] = []
        if let knowledgeSet = memoryEntity.knowledge as? Set<FactEntity> {
            facts = knowledgeSet.map { factEntity in
                Fact(key: factEntity.key ?? "", value: factEntity.value ?? "")
            }
        }
        
        // Map emotionalState: Convert EmotionEntity set to [Emotion].
        var emotions: [Emotion] = []
        if let emotionSet = memoryEntity.emotionalState as? Set<EmotionEntity> {
            emotions = emotionSet.map { emotionEntity in
                let label: EmotionLabel? = emotionEntity.label.flatMap { EmotionLabel.from($0) }
                return Emotion(pleasure: emotionEntity.pleasure,
                               arousal: emotionEntity.arousal,
                               dominance: emotionEntity.dominance,
                               label: label,
                               timestamp: emotionEntity.timestamp ?? Date())
            }
        }
        
        // Compute today's emotion (e.g., the most recent emotion recorded today).
        let calendar = Calendar.current
        var todaysEmotion = emotions
            .filter { calendar.isDateInToday($0.timestamp) }
            .reduce(into: Emotion(pleasure: 0, arousal: 0, dominance: 0, timestamp: Date())) { result, emotion in
                result.arousal += emotion.arousal
                result.dominance += emotion.dominance
                result.pleasure += emotion.pleasure
            }
        todaysEmotion.label = EmotionLabel.from(pleasure: todaysEmotion.pleasure, arousal: todaysEmotion.arousal, dominance: todaysEmotion.dominance)
        
        return Memory(personality: personalityProfile,
                      knowledge: facts,
                      emotionalState: emotions,
                      todaysEmotion: todaysEmotion)
    }
    
    /// Update the current user's memory with the provided Memory model.
    func updateMemory(_ memory: Memory) {
        guard let userId = authService.currentUser?.id else { return }
        
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        
        if let userEntity = try? context.fetch(userRequest).first,
           let memoryEntity = userEntity.memory {
            // Update personality.
            if let personality = memory.personality {
                let personalityEntity: PersonalityProfileEntity
                if let existing = memoryEntity.personality {
                    personalityEntity = existing
                } else {
                    personalityEntity = PersonalityProfileEntity(context: context)
                    memoryEntity.personality = personalityEntity
                }
                personalityEntity.mbti = personality.mbti.rawValue
                // Update BigFive.
                personalityEntity.bigFive_openness = personality.bigFive.openness
                personalityEntity.bigFive_conscientiousness = personality.bigFive.conscientiousness
                personalityEntity.bigFive_extraversion = personality.bigFive.extraversion
                personalityEntity.bigFive_agreeableness = personality.bigFive.agreeableness
                personalityEntity.bigFive_neuroticism = personality.bigFive.neuroticism
                // Update HEXACO.
                personalityEntity.hexaco_opennessToExperience = personality.hexaco.opennessToExperience
                personalityEntity.hexaco_honestyHumility = personality.hexaco.honestyHumility
                personalityEntity.hexaco_extraversion = personality.hexaco.extraversion
                personalityEntity.hexaco_emotionality = personality.hexaco.emotionality
                personalityEntity.hexaco_conscientiousness = personality.hexaco.conscientiousness
                personalityEntity.hexaco_agreeableness = personality.hexaco.agreeableness
            } else {
                // Remove existing personality if new one is nil.
                if let personalityEntity = memoryEntity.personality {
                    context.delete(personalityEntity)
                    memoryEntity.personality = nil
                }
            }
            
            // Declare a variable to hold the existing facts
            var existingFacts: Set<FactEntity> = memoryEntity.knowledge as? Set<FactEntity> ?? []

            // Delete the old facts from the context
            for factEntity in existingFacts {
                context.delete(factEntity)
            }

            // Create new FactEntity objects
            var newFacts = Set<FactEntity>()
            for fact in memory.knowledge {
                let factEntity = FactEntity(context: context)
                factEntity.key = fact.key
                factEntity.value = fact.value
                newFacts.insert(factEntity)
            }

            // Combine the two sets into one
            let combinedFacts = existingFacts.union(newFacts)
            memoryEntity.knowledge = combinedFacts as NSSet

            
            // Update emotionalState: Remove current EmotionEntity objects.
            var existingEmotions: Set<EmotionEntity> = memoryEntity.emotionalState as? Set<EmotionEntity> ?? []
            
            for emotionEntity in existingEmotions {
                context.delete(emotionEntity)
            }
            
            var newEmotions = Set<EmotionEntity>()
            for emotion in memory.emotionalState {
                let emotionEntity = EmotionEntity(context: context)
                emotionEntity.pleasure = emotion.pleasure
                emotionEntity.arousal = emotion.arousal
                emotionEntity.dominance = emotion.dominance
                emotionEntity.label = emotion.label?.rawValue
                emotionEntity.timestamp = emotion.timestamp
                newEmotions.insert(emotionEntity)
            }
            
            let combinedEmotions = existingEmotions.union(newEmotions)
            memoryEntity.emotionalState = combinedEmotions as NSSet
            
            do {
                try context.save()
            } catch {
                print("Error updating memory: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove the memory from the current user.
    func clearMemory() {
        guard let userId = authService.currentUser?.id else { return }
        
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        
        if let userEntity = try? context.fetch(userRequest).first {
            if let memoryEntity = userEntity.memory {
                // Optionally delete the MemoryEntity from context.
                context.delete(memoryEntity)
            }
            userEntity.memory = nil
            do {
                try context.save()
            } catch {
                print("Error clearing memory: \(error.localizedDescription)")
            }
        }
    }
}

