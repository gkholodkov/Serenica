//
//  ReasoningService.swift
//  Serenica
//
//  Created by Checkito12 on 09.03.25.
//
import Foundation

class DeepSeekReasoningService: ReasoningServiceProtocol {
    private let apiKey: String
    private let baseURL: String
    
    public init(apiKey: String = "test-key", baseURL: String = "https://api.deepseek.com/v1/chat/completions")
    {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func processMessage(_ message: String, userContext: String) async -> String {
        do {
            var request = URLRequest(url: URL(string: baseURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let contextMessage = ChatMessage(role: .assistant, content: userContext)
            
            // Combine system message, previous messages, and new message
            let allMessages = [analysisPrompt, contextMessage] + [ChatMessage(role: .assistant, content: message)]
            
            let chatRequest = ChatRequest(
                model: "deepseek-reasoner",
                messages: allMessages,
                temperature: 1,
                tools: nil,
                tool_choice: nil
            )
            
            let jsonData = try JSONEncoder().encode(chatRequest)
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            return response.choices.first?.message.content ?? ""
        } catch {
            return ""
        }
    }
}
