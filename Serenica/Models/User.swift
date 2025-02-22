import Foundation
import CryptoKit

struct User: Codable, Equatable {
    let id: UUID
    let username: String
    let hashedPassword: String
    let createdAt: Date
    
    init(id: UUID = UUID(), username: String, password: String, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.hashedPassword = User.hashPassword(password)
        self.createdAt = createdAt
    }
    
    static func hashPassword(_ password: String) -> String {
        let salt = "serenica_salt" // In production, use a unique salt per user
        let saltedPassword = password + salt
        let hashedData = SHA256.hash(data: saltedPassword.data(using: .utf8)!)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Equatable conformance is automatically synthesized
    // since all properties are already Equatable
} 
