import Foundation

struct ChatRequest: Codable {
    let model: String          // If the API still requires the model name.
    let messages: [ChatMessage]
    let temperature: Double?
    let tools: [Tool]?
    let tool_choice: ToolChoice?
    let response_format: ResponseFormat?
}

struct ResponseFormat: Codable {
    let type: ResponseFormatType
    let json_schema: JSONSchemaDefinition?
}

enum ResponseFormatType: String, Codable {
    case jsonSchema = "json_schema"
    case text = "text"
}

struct JSONSchemaDefinition: Codable {
    let name: String
    let strict: Bool
    let schema: JSONSchema
}

struct JSONSchema: Codable {
    let type: ParameterType
    let properties: [String: JSONSchemaProperty]
    let required: [String]
    let additionalProperties: Bool
}

struct JSONSchemaProperty: Codable {
    let type: ParameterType
    let description: String?
    let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }
}

enum ToolChoice: String, Codable {
    case none
    case auto
    case required
}

struct ChatMessage: Codable, Equatable {
    let role: MessageRole
    /// `name` is optional but can be used when role is "tool message" or "function".
    let name: String?
    let content: String
    let tool_calls: [ToolCall]?
    let tool_call_id: String?
    let prefix: Bool?
    
    init(role: MessageRole, content: String, name: String? = nil, tool_calls: [ToolCall]? = nil, tool_call_id: String? = nil, prefix: Bool? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.prefix = prefix
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.role == rhs.role &&
                lhs.name == rhs.name &&
                lhs.content == rhs.content &&
                lhs.tool_calls == rhs.tool_calls &&
                lhs.tool_call_id == rhs.tool_call_id &&
                lhs.prefix == rhs.prefix
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}


struct Tool: Codable {
    let type: ToolType
    let function: Function
}

enum ToolType: String, Codable {
    case function
}

// MARK: - Function Definition

struct Function: Codable {
    let description: String
    let name: FunctionName
    let parameters: FunctionParams
}

struct FunctionParams: Codable {
    let type: ParameterType
    let properties: [String: ParameterDefinition]
    let required: [String]?
    let additionalProperties: Bool
}

enum FunctionName: String, Codable {
    case createEvent
    case getEvents
    case modifyEvent
    case classifyEmotion
    case updateKnowledge
}


struct ParameterDefinition: Codable {
    let type: ParameterType
    let description: String
    let enumValues: [String]?  // For enum types
    let minimum: Double?
    let maximum: Double?

    enum CodingKeys: String, CodingKey {
        case type, description, minimum, maximum
        case enumValues = "enum"
    }
}

enum ParameterType: String, Codable {
    case string
    case integer
    case boolean
    case object
    case number
    case array
}

/// Represents the entire response returned by the DeepSeek API.
struct ChatResponse: Codable {
    /// The name of the model used, e.g., "deepseek-chat" or "deepseek-reasoner".
    let model: String
    /// An array of choices produced by the model.
    let choices: [Choice]
}

/// A single choice in the response array.
struct Choice: Codable {
    /// Why the model stopped generating tokens.
    /// e.g. "stop", "length", "content_filter", "tool_calls", or "insufficient_system_resource".
    let finish_reason: String
    /// The resulting message from the model.
    let message: ChoiceMessage
}

/// The assistant’s response message (or partial message) within a choice.
struct ChoiceMessage: Codable {
    /// The final text output from the assistant (nullable if the model instead called a tool).
    let content: String?
    /// The role of this message, typically "assistant".
    let role: String
    /// Any tool calls the assistant decided to make (if `finish_reason` = "tool_calls").
    let tool_calls: [ToolCall]?
}

/// A record of a single tool call invoked by the model.
struct ToolCall: Codable, Equatable {
    /// A unique ID for this tool call.
    let id: String
    /// Currently only "function" is supported by the API.
    let type: String?
    /// The function the model called.
    let function: ToolFunction
    
    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        return lhs.id == rhs.id &&
                lhs.function == rhs.function &&
                lhs.type == rhs.type
    }
}

/// A function call invoked by the model/tool call.
struct ToolFunction: Codable, Equatable {
    /// The name of the function the model decided to call.
    let name: String
    /// The arguments the model passed to that function.
    /// The model might return these as JSON (e.g. `"{\"param\":\"value\"}"`).
    let arguments: String
    
    static func == (lhs: ToolFunction, rhs: ToolFunction) -> Bool {
        return lhs.name == rhs.name &&
        lhs.arguments == rhs.arguments
    }
}

struct EmotionRecognitionResponse: Decodable {
    let pleasure: Double
    let arousal: Double
    let dominance: Double
    let label: String
}
