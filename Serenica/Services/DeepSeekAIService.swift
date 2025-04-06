import Foundation

class DeepSeekAIService : AIServiceProtocol {
    private let apiKey: String
    private let baseURL: String
    
    public init(apiKey: String = "test-key", baseURL: String = "https://api.deepseek.com/v1/chat/completions")
    {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func getNaturalLanguageResponse(_ message: String, prefixMessage: ChatMessage? = nil, shortTermMemory: [ChatMessage]? = nil, longTermMemory: ChatMessage? = nil) async throws -> [Choice] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Convert our Message models to ChatMessage format
        let recentChatMessages = shortTermMemory ?? []
        let importantInformationsMessages = [systemMessage, longTermMemory].filter { $0 != nil }.compactMap { $0 }
                
        // Combine system message, previous messages, and new message
        let allMessages = prefixMessage != nil
        ? importantInformationsMessages + recentChatMessages + [ChatMessage(role: .user, content: message), prefixMessage!]
        : importantInformationsMessages + recentChatMessages + [ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.7,
            tools: [],
            tool_choice: ToolChoice.none
        )
        
        let jsonData = try JSONEncoder().encode(chatRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        return response.choices
    }
    
    func getToolCallsResponse(_ message: String, shortTermMemory: [ChatMessage]? = nil) async throws -> [ToolCall] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let currentDatePrompt = ChatMessage(role: .system, content: "Today is \(Date().ISO8601Format())")
        let recentChatMessages = shortTermMemory ?? []
        
        let allMessages = [currentDatePrompt] + recentChatMessages + [ChatMessage(role: .user, content: message)]
        
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.0,
            tools: tools,
            tool_choice: .auto
        )
        
        let jsonData = try JSONEncoder().encode(chatRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        return response.choices.first?.message.tool_calls ?? []
    }
    
    func getEmotionRecognitionResponse(_ message: String) async throws -> EmotionRecognitionResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Convert our Message models to ChatMessage format
                
        // Combine system message, previous messages, and new message
        let allMessages = [emotionRecognitionMessage, ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.0,
            tools: [],
            tool_choice: ToolChoice.none
        )
        
        let jsonData = try JSONEncoder().encode(chatRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        let emotionRecognitionData = response.choices.first?.message.content?.data(using: .utf8)
        
        let recognitionResponse = emotionRecognitionData != nil ? try JSONDecoder().decode(EmotionRecognitionResponse.self, from: emotionRecognitionData!) : EmotionRecognitionResponse(pleasure: 0, arousal: 0.5, dominance: 0.5, label: EmotionLabel.calm.rawValue)
        
        return recognitionResponse
    }
}
