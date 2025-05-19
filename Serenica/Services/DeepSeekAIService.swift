import Foundation

class DeepSeekAIService: AIServiceProtocol {
    private let apiKey: String
    private let baseURL: String
    private let httpClient: HttpClient

    public init(apiKey: String = "test-key",
                baseURL: String = "https://api.deepseek.com/v1/chat/completions",
                retryCount: Int = 3,
                retryDelay: TimeInterval = 2) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = HttpClient(retryCount: retryCount, retryDelay: retryDelay)
    }
    
    /// Gets the natural language response using retry logic.
    func getNaturalLanguageResponse(newOrderedMessages: [ChatMessage],
                                    shortTermMemory: [ChatMessage]? = nil,
                                    longTermMemory: ChatMessage? = nil) async throws -> [Choice] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let recentChatMessages = shortTermMemory ?? []
        let importantInformationMessages = [systemMessage, longTermMemory].compactMap { $0 }
        
        // Combine system message, previous messages, and the new message.
        let allMessages = importantInformationMessages + recentChatMessages + newOrderedMessages
        
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.7,
            tools: [],
            tool_choice: ToolChoice.none,
            response_format: nil
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices
    }
    
    /// Gets tool calls response using retry logic.
    func getToolCallsResponse(newOrderedMessages: [ChatMessage],
                              shortTermMemory: [ChatMessage]? = nil) async throws -> [ToolCall] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let currentDatePrompt = ChatMessage(role: .system, content: "Today is \(Date().ISO8601Format())")
        let recentChatMessages = shortTermMemory ?? []
        let allMessages = [currentDatePrompt] + recentChatMessages + newOrderedMessages
        
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.0,
            tools: tools,
            tool_choice: .auto,
            response_format: nil
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices.first?.message.tool_calls ?? []
    }
    
    /// Gets emotion recognition response using retry logic.
    func getEmotionRecognitionResponse(_ message: String) async throws -> EmotionRecognitionResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let allMessages = [emotionRecognitionMessage, ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
            model: "deepseek-chat",
            messages: allMessages,
            temperature: 0.0,
            tools: [],
            tool_choice: ToolChoice.none,
            response_format: nil
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        if let content = response.choices.first?.message.content,
           let emotionData = content.data(using: .utf8) {
            return try JSONDecoder().decode(EmotionRecognitionResponse.self, from: emotionData)
        } else {
            return EmotionRecognitionResponse(pleasure: 0, arousal: 0.5, dominance: 0.5, label: EmotionLabel.neutrality.rawValue)
        }
    }
    
    func getFactExtractionResponse(_ message: String, factContext: [String], messageHistory: [ChatMessage]? = nil) async throws -> [Fact] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let allMessages = [factExtractionMessage] + (messageHistory ?? []) + [ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
                model: "deepseek-chat",
                messages: allMessages,
                temperature: 0.0,
                tools: [factExtractionTool(facts: factContext)],
                tool_choice: .required,
                response_format: nil
            )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        var newFacts: [Fact] = []
        for toolCall in response.choices.first?.message.tool_calls ?? [] {
            guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                continue
            }
            let decodedArgs = try JSONDecoder().decode(FactArgs.self, from: argsData)
            newFacts.append(Fact(key: decodedArgs.factKey, value: decodedArgs.factValue, ttl: decodedArgs.timeToLive, timestamp: Date(), importance: 0))
        }
        
        return newFacts
    }
}
