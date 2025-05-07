#if DEBUG
import SwiftUI
import CoreData

extension View {
    func withPreviewDependencies() -> some View {
        let context = CoreDataManager.shared.viewContext
        let authService = AuthService(context: context)
        let eventService = EventService(context: context)
        let mistral = MistralAIService()
        let aiAgent = AIAppAgent(authService: authService, memoryService: AgentMemoryService(context: context), aiService: mistral, emotionRecognitionService: EmotionRecognitionService(llmService: mistral), factExtractionService: FactExtractionService(llmService: mistral), personalityCreationService: PersonalityCreationService(), eventService: eventService, eventContextManager: EventContextManager())
        let messageService = MessageService(context: context, aiAgent: aiAgent)
        return self
            .environment(\.managedObjectContext, context)
            .environmentObject(authService)
            .environmentObject(messageService)
            .environmentObject(eventService)
    }
}

extension AuthService {
    static func previewWithUser() -> AuthService {
        let service = AuthService(context: CoreDataManager.shared.viewContext)
        // Set a mock user for preview
        // Note: You might need to add a method to set currentUser directly
        return service
    }
}
#endif 
