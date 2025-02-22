import Foundation
import CoreData

class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    private let userDefaults = UserDefaults.standard
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.currentUser = nil  // Explicitly set to nil
        tryAutoLogin()
    }
    
    private func tryAutoLogin() {
        // Clear any existing data in preview mode
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            userDefaults.removeObject(forKey: "currentUser")
            return
        }
        #endif
        
        if let userData = userDefaults.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
        }
    }
    
    func signIn(username: String, password: String) throws {
        let request = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        request.predicate = NSPredicate(format: "username == %@", username)
        
        guard let userEntity = try context.fetch(request).first else {
            throw AuthError.invalidCredentials
        }
        
        let hashedPassword = User.hashPassword(password)
        guard hashedPassword == userEntity.hashedPassword else {
            throw AuthError.invalidCredentials
        }
        
        let user = User(
            id: userEntity.id ?? UUID(),
            username: userEntity.username ?? "",
            password: password,
            createdAt: userEntity.createdAt ?? Date()
        )
        
        currentUser = user
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: "currentUser")
        }
    }
    
    func signUp(username: String, password: String) throws {
        // Check if username already exists
        let request = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        request.predicate = NSPredicate(format: "username == %@", username)
        
        if try !context.fetch(request).isEmpty {
            throw AuthError.usernameTaken
        }
        
        // Create new user
        let userEntity = UserEntity(context: context)
        userEntity.id = UUID()
        userEntity.username = username
        userEntity.hashedPassword = User.hashPassword(password)
        userEntity.createdAt = Date()
        
        try context.save()
        
        // Auto sign in after successful registration
        try signIn(username: username, password: password)
    }
    
    func signOut() {
        currentUser = nil
        userDefaults.removeObject(forKey: "currentUser")
    }
    
    enum AuthError: LocalizedError {
        case invalidCredentials
        case usernameTaken
        
        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid username or password"
            case .usernameTaken:
                return "Username is already taken"
            }
        }
    }
    
    enum PasswordResetError: LocalizedError {
        case userNotFound
        case invalidPassword
        case samePassword
        
        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "No account found with this username"
            case .invalidPassword:
                return "Password must be at least 6 characters long"
            case .samePassword:
                return "New password must be different from the current one"
            }
        }
    }
    
    func sendPasswordResetLink(username: String) async throws {
        let request = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        request.predicate = NSPredicate(format: "username == %@", username)
        
        // Just check if user exists
        guard try !context.fetch(request).isEmpty else {
            throw PasswordResetError.userNotFound
        }
        
        try await Task.sleep(for: .seconds(1)) // Simulate network request
    }
    
    func resetPassword(username: String, newPassword: String) async throws {
        guard newPassword.count >= 6 else {
            throw PasswordResetError.invalidPassword
        }
        
        let request = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        request.predicate = NSPredicate(format: "username == %@", username)
        
        guard let userEntity = try context.fetch(request).first else {
            throw PasswordResetError.userNotFound
        }
        
        let newHashedPassword = User.hashPassword(newPassword)
        if newHashedPassword == userEntity.hashedPassword {
            throw PasswordResetError.samePassword
        }
        
        userEntity.hashedPassword = newHashedPassword
        try context.save()
        
        // If the user was logged in, update their credentials
        if let currentUserId = currentUser?.id, currentUserId == userEntity.id {
            let updatedUser = User(
                id: userEntity.id ?? UUID(),
                username: userEntity.username ?? "",
                password: newPassword,
                createdAt: userEntity.createdAt ?? Date()
            )
            
            // Update the published property on the main thread
            await MainActor.run {
                self.currentUser = updatedUser
            }
            
            if let encoded = try? JSONEncoder().encode(updatedUser) {
                userDefaults.set(encoded, forKey: "currentUser")
            }
        }
    }
} 
