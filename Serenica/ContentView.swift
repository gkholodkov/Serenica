import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService: AuthService
    
    init(context: NSManagedObjectContext) {
        _authService = StateObject(wrappedValue: AuthService(context: context))
    }
    
    var body: some View {
        NavigationView {
            MainTabView(context: viewContext)
        }
    }
}

#Preview {
    ContentView(context: CoreDataManager.shared.viewContext)
        .withPreviewDependencies()
}

