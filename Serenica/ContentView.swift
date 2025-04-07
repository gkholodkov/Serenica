import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Create shared service instances.
    @StateObject private var authService: AuthService
    @StateObject private var eventService: EventService
    @StateObject private var messageService: MessageService

    init(context: NSManagedObjectContext) {
        // Instantiate AuthService using the provided context.
        let auth = AuthService(context: context)
        
        // Create the EventService (it uses the same context).
        let eventSvc = EventService(context: context)
        
        // Build the AI agent for MessageService.
        let memoryService = AgentMemoryService(context: context)
        let aiService = MistralAIService()
        let emotionRecognitionService = EmotionRecognitionService(llmService: aiService)
        let eventContextManager = EventContextManager()

        let aiAgent = AIEventAgent(
            authService: auth,
            memoryService: memoryService,
            aiService: aiService,
            emotionRecognitionService: emotionRecognitionService,
            eventService: eventSvc,
            eventContextManager: eventContextManager
        )
        
        // Create the MessageService using the same context and our aiAgent.
        let msgSvc = MessageService(context: context, aiAgent: aiAgent)
        
        // Set up our state objects.
        _authService = StateObject(wrappedValue: auth)
        _eventService = StateObject(wrappedValue: eventSvc)
        _messageService = StateObject(wrappedValue: msgSvc)
    }

    var body: some View {
        NavigationView {
            MainTabView() 
        }
        .environment(\.managedObjectContext, viewContext)
        // Inject the shared services instance.
        .environmentObject(authService)
        .environmentObject(eventService)
        .environmentObject(messageService)
    }
}


#Preview {
    ContentView(context: CoreDataManager.shared.viewContext)
        .withPreviewDependencies()
}
