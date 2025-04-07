import Foundation

class MistralAIService: AIServiceProtocol {
    private let apiKey: String
    private let baseURL: String
    private let httpClient: HttpClient
    
    public init(apiKey: String = "test-key",
                baseURL: String = "https://api.mistral.ai/v1/chat/completions",
                retryCount: Int = 3,
                retryDelay: TimeInterval = 2) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = HttpClient(retryCount: retryCount, retryDelay: retryDelay)
    }
    
    func getNaturalLanguageResponse(_ message: String, prefixMessage: ChatMessage?, shortTermMemory: [ChatMessage]?, longTermMemory: ChatMessage?) async throws -> [Choice] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let recentChatMessages = shortTermMemory ?? []
        let importantInformationMessages = [systemMessage, longTermMemory].compactMap { $0 }
        
        // Combine system message, previous messages, and the new message.
        let allMessages: [ChatMessage]
        if let prefix = prefixMessage {
            allMessages = importantInformationMessages + recentChatMessages + [ChatMessage(role: .user, content: message), prefix]
        } else {
            allMessages = importantInformationMessages + recentChatMessages + [ChatMessage(role: .user, content: message)]
        }
        
        let chatRequest = ChatRequest(
            model: "mistral-large-latest",
            messages: allMessages,
            temperature: 0.7,
            tools: [],
            tool_choice: ToolChoice.none
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices
    }
    
    func getToolCallsResponse(_ message: String, shortTermMemory: [ChatMessage]?) async throws -> [ToolCall] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let currentDatePrompt = ChatMessage(role: .system, content: "Today is \(Date().ISO8601Format())")
        let recentChatMessages = shortTermMemory ?? []
        let allMessages = [currentDatePrompt] + recentChatMessages + [ChatMessage(role: .user, content: message)]
        
        let chatRequest = ChatRequest(
            model: "mistral-large-latest",
            messages: allMessages,
            temperature: 0.0,
            tools: tools,
            tool_choice: .auto
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
                
        let (data, _) = try await httpClient.performRequest(with: request)
        print(String(data: data, encoding: .utf8) ?? "No data returned")
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        print(response)
        return response.choices.first?.message.tool_calls ?? []
    }
    
    func getEmotionRecognitionResponse(_ message: String) async throws -> EmotionRecognitionResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let allMessages = [emotionRecognitionMessage, ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
            model: "mistral-large-latest",
            messages: allMessages,
            temperature: 0.0,
            tools: [],
            tool_choice: ToolChoice.none
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        if let content = response.choices.first?.message.content,
           let emotionData = content.data(using: .utf8) {
            return try JSONDecoder().decode(EmotionRecognitionResponse.self, from: emotionData)
        } else {
            return EmotionRecognitionResponse(pleasure: 0, arousal: 0.5, dominance: 0.5, label: EmotionLabel.calm.rawValue)
        }
    }
    
    
}
