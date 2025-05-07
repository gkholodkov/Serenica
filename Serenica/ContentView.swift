import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var messageService: MessageService


    var body: some View {
        NavigationView {
            MainTabView()
                // ③ Hook into “view disappears”:
                .onDisappear {
                    Task { await messageService.onEndConversation(reason: .viewDismissed) }
                }
        }
        .environment(\.managedObjectContext, viewContext)
    }
}


#Preview {
    ContentView()
        .withPreviewDependencies()
}
