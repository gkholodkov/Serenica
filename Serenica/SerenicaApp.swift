import SwiftUI

@main
struct SerenicaApp: App {
    let persistenceController = CoreDataManager.shared
    
    @StateObject private var authService: AuthService
    @StateObject private var eventService: EventService
    @StateObject private var messageService: MessageService
    
    init() {
        let context = persistenceController.viewContext

        // your existing service graph…
        let auth = AuthService(context: context)
        let eventSvc = EventService(context: context, authService: auth)
        let memoryService = AgentMemoryService(context: context, authService: auth)
        let aiService = MistralAIService()
        let emotionRecognitionService = EmotionRecognitionService(llmService: aiService)
        let factExtractionService = FactExtractionService(llmService: aiService)
        let personalityCreationService = PersonalityCreationService()
        let eventContextManager = EventContextManager()

        let aiAgent = AIAppAgent(
            authService: auth,
            memoryService: memoryService,
            aiService: aiService,
            emotionRecognitionService: emotionRecognitionService,
            factExtractionService: factExtractionService,
            personalityCreationService: personalityCreationService,
            eventService: eventSvc,
            eventContextManager: eventContextManager
        )
        let msgSvc = MessageService(context: context, authService: auth, aiAgent: aiAgent)

        _authService = StateObject(wrappedValue: auth)
        _eventService = StateObject(wrappedValue: eventSvc)
        _messageService = StateObject(wrappedValue: msgSvc)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(authService)
                .environmentObject(eventService)
                .environmentObject(messageService)
                // ② Hook into “app backgrounds”:
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willResignActiveNotification
                    )
                ) { _ in
                    Task { await messageService.onEndConversation(reason: .appBackground) }
                }
        }
    }
}
