import Foundation

class DeepSeekService : AIServiceProtocol {    
    private let apiKey: String
    private let baseURL: String
    
    public init(apiKey: String = "test-key", baseURL: String = "https://api.deepseek.com/v1/chat/completions")
    {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func sendMessage(_ message: String, previousMessages: [Message]) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Convert our Message models to ChatMessage format
        let chatMessages = previousMessages.map { message in
            ChatMessage(
                role: message.isFromUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        // Combine system message, previous messages, and new message
        let allMessages = [systemMessage] + chatMessages + [ChatMessage(role: "user", content: message)]
        
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.7,
            tools: nil
        )
        
        let jsonData = try JSONEncoder().encode(chatRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "I apologize, but I couldn't generate a response."
    }
} 
