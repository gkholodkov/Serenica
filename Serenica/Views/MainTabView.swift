import SwiftUI
import CoreData

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext

    // Remove the custom initializer and StateObject creation.
    var body: some View {
        if authService.currentUser != nil {
            TabView {
                // Chat tab
                NavigationStack {
                    ChatView()
                        .navigationTitle("Hello, \(authService.currentUser?.username ?? "")")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Sign Out") {
                                    authService.signOut()
                                }
                            }
                        }
                }
                .tabItem {
                    Image(systemName: "captions.bubble")
                        .frame(width: 20, height: 20)
                }

                // Calendar tab
                NavigationStack {
                    ToDoView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Image(systemName: "calendar")
                        .frame(width: 20, height: 20)
                }
            }
            .overlay(
                Divider()
                    .background(Serenity.Colors.divider)
                    .opacity(0.5),
                alignment: .top
            )
            .tint(Serenity.Colors.primary)
        } else {
            AuthView()
        }
    }
}

#Preview {
    MainTabView()
        .withPreviewDependencies()
}
