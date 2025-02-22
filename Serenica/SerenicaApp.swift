import SwiftUI

@main
struct SerenicaApp: App {
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.viewContext)
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
