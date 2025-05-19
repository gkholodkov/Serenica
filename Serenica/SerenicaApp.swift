import SwiftUI
import UserNotifications

@main
struct SerenicaApp: App {
    let persistenceController = CoreDataManager.shared
    
    @StateObject private var authService: AuthService
    @StateObject private var eventService: EventService
    @StateObject private var messageService: MessageService
    
    init() {
        let context = persistenceController.viewContext
        _ = NotificationManager.shared

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
        
        // Request notifications permission once at app startup:
        requestNotificationPermissionOnce()
        verifyNotificationPermissions()
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
                    Task { await messageService.onEndConversation() }
                }
        }
    }
    
    func requestNotificationPermissionOnce() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                print("Notifications already requested or user has responded.")
                return
            }
            
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error = error {
                    print("Notification authorization failed: \(error.localizedDescription)")
                } else {
                    print("Notifications granted: \(granted)")
                }
            }
        }
    }
    
    func verifyNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .authorized:
                print("✅ Authorized")
            case .denied:
                print("🚫 Denied")
            case .notDetermined:
                print("❓ Not Determined")
            case .provisional:
                print("⚠️ Provisional")
            case .ephemeral:
                print("⚠️ Ephemeral")
            @unknown default:
                print("⚠️ Unknown Status")
            }
        }
    }
}
