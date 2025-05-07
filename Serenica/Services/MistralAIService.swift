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
        
        print("Natural Language Messages: \(allMessages.map{ message in return "\(message.role): \(message.content), tools: \(message.tool_calls?.first?.function.name ?? "none")" }.joined(separator: "\n"))")
        
        let chatRequest = ChatRequest(
            model: "mistral-large-latest",
            messages: allMessages,
            temperature: 0.7,
            tools: [],
            tool_choice: ToolChoice.none,
            response_format: nil
        )
        
        let httpBody = try JSONEncoder().encode(chatRequest)
        request.httpBody = httpBody
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices
    }
    
    func getToolCallsResponse(_ message: String, shortTermMemory: [ChatMessage]?) async throws -> [ToolCall] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let currentDatePrompt = ChatMessage(role: .system, content: "Today is \(Date().ISO8601Format()).")
        let recentChatMessages = shortTermMemory ?? []
        let allMessages = [currentDatePrompt] + recentChatMessages + [ChatMessage(role: .user, content: message)]
        
        print("Tool Call Messages: \(allMessages.map{ message in return "\(message.role): \(message.content), tools: \(message.tool_calls?.first?.function.name ?? "none")" }.joined(separator: "\n"))")
        
        let chatRequest = ChatRequest(
            model: "mistral-large-latest",
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
            tool_choice: ToolChoice.none,
            response_format: ResponseFormat(
                type: .jsonSchema,
                json_schema: JSONSchemaDefinition(name: "PADEmotionRecognition", strict: true, schema: emotionSchema
                )
            )
        )
        
        print("Here's the chat request: \(chatRequest)")
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        print(String(data: request.httpBody!, encoding: .utf8)!)
        
        let (data, _) = try await httpClient.performRequest(with: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let argsData = response.choices.first?.message.content?.data(using: .utf8) else {
            print("Default emotion: (0, 0.5, 0.5, calm)")
            return EmotionRecognitionResponse(pleasure: 0, arousal: 0.5, dominance: 0.5, label: EmotionLabel.neutrality.rawValue)
        }
        
        let decodedArgs = try JSONDecoder().decode(EmotionArgs.self, from: argsData)
        
        print("LLM Emotion Recognition Successful")
        
        return EmotionRecognitionResponse(pleasure: decodedArgs.pleasure, arousal: decodedArgs.arousal, dominance: decodedArgs.dominance, label: decodedArgs.label)
    }
    
    func getFactExtractionResponse(_ message: String, factContext: [String], messageHistory: [ChatMessage]? = nil) async throws -> [Fact] {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let allMessages = [factExtractionMessage] + (messageHistory ?? []) + [ChatMessage(role: .user, content: message)]
        let chatRequest = ChatRequest(
                model: "mistral-large-latest",
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
            newFacts.append(Fact(key: decodedArgs.factKey, value: decodedArgs.factValue, ttl: decodedArgs.timeToLive, timestamp: Date(), importance: decodedArgs.importance))
        }
        
        print("LLM Facts Extraction Successful")
        
        return newFacts
    }
}
