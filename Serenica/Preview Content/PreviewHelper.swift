#if DEBUG
import SwiftUI
import CoreData

extension View {
    func withPreviewDependencies() -> some View {
        let context = CoreDataManager.shared.viewContext
        let authService = AuthService(context: context)
        return self
            .environment(\.managedObjectContext, context)
            .environmentObject(authService)
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

extension MessageStore {
    static func previewWithMessages() -> MessageStore {
        let store = MessageStore()
        store.previewAddMessage(Message(
            content: "Hello! How can I help you today?",
            isFromUser: false
        ))
        store.previewAddMessage(Message(
            content: "I need help with SwiftUI",
            isFromUser: true
        ))
        return store
    }
}
#endif 
