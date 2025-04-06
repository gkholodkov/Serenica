import Foundation

protocol AIServiceProtocol {
    /// A common system message that is shared by all implementations to generate NLP response.
    var systemMessage: ChatMessage { get }
    
    /// A common emotion and sentiment recognition prompt shared by all implementations
    var emotionRecognitionMessage: ChatMessage { get }
        
    /// A common toolset that is shared by all implementations
    var tools: [Tool] { get }
    
    /// Sends a chat request
    func getNaturalLanguageResponse(_ message: String, prefixMessage: ChatMessage?, shortTermMemory: [ChatMessage]?, longTermMemory: ChatMessage?) async throws -> [Choice]
    
    func getToolCallsResponse(_ message: String, shortTermMemory: [ChatMessage]?) async throws -> [ToolCall]
    
    func getEmotionRecognitionResponse(_ message: String) async throws -> EmotionRecognitionResponse
}

protocol ReasoningServiceProtocol {
    var analysisPrompt: ChatMessage { get }
    /// Asynchronously processes a user message to extract additional knowledge.
    func processMessage(_ message: String, userContext: String) async -> String
}

extension ReasoningServiceProtocol {
    var analysisPrompt: ChatMessage {
        ChatMessage(
            role: .system,
            content: """
            Analyze the following user message and extract any new knowledge about the user (for example, changes in mood, new interests, relationships, or triggers). Return a concise plain text summary. If no new knowledge is detected, return an empty string.
            """
        )
    }
}

extension AIServiceProtocol {
    var systemMessage: ChatMessage {
        ChatMessage(
            role: .system,
            content: """
            You're an empathetic mental health counselor familiar with German culture, replying warmly in English and in clear, natural language. Be sensitive to ADHD, ASD, and MDD, offering tailored encouragement, coping strategies, and German resources (adhdeurope.eu, adhs-deutschland.de). If severe issues (e.g., suicidal thoughts, self-harm, psychosis symptoms) arise, remind users you're not a substitute for professional help and advise crisis support: Telefonseelsorge (0800 111 0 111/0 222), International Helpline Berlin (030-44 01 06 07), Nummer gegen Kummer (0800 111 0 550). Keep responses concise (~120 chars max). If user asked you to do something, reassure it with user before the actual execution.
            """
        )
    }
    
    var emotionRecognitionMessage: ChatMessage {
        ChatMessage(
            role: .system,
            content: """
            You're an emotion analyzer using PAD (Pleasure, Arousal, Dominance) model. Return JSON only. Analyze the emotional sentiment of user messages. Provide your response as a valid object of the scheme:\n\n{\n  \"pleasure\": Double (-1.0 to 1.0),\n  \"arousal\": Double (0.0 to 1.0),\n  \"dominance\": Double (0.0 to 1.0),\n  \"label\": String (one of: anger, joy, sadness, happiness, fear, surprise, disgust, calm, confusion, guilt, shame, pride, jealousy, envy, nostalgia, ambivalence, curiosity, contempt, awe, bittersweet, schadenfreude, honor, dignity, excitement, regret)\n}\n
            """
        )
    }
    
    var tools: [Tool] {
        [
            Tool(
                type: .function,
                function: Function(
                    description: "Fetch events by date or title query. Use it to fetch event context data or if user requested you to show his events",
                    name: .getEvents,
                    parameters: FunctionParams(
                        type: .object,
                        properties: [
                            "date": ParameterDefinition(
                                type: .string,
                                description: "Date to filter events (ISO8601)",
                                enumValues: nil
                            ),
                            "titleQuery": ParameterDefinition(
                                type: .string,
                                description: "Part of the event title to search",
                                enumValues: nil
                            )
                        ],
                        required: nil,
                        additionalProperties: false
                    )
                )
            ),
            Tool(
                type: .function,
                function: Function(
                    description: "Creates a calendar event",
                    name: .createEvent,
                    parameters: FunctionParams(
                        type: .object,
                        properties: [
                            "title": ParameterDefinition(
                                type: .string,
                                description: "Title of the event",
                                enumValues: nil
                            ),
                            "startDate": ParameterDefinition(
                                type: .string,
                                description: "Event start (ISO8601)",
                                enumValues: nil
                            ),
                            "endDate": ParameterDefinition(
                                type: .string,
                                description: "Event end (ISO8601)",
                                enumValues: nil
                            ),
                            "notificationInterval": ParameterDefinition(
                                type: .integer,
                                description: "Number of minutes before the event start user wants to be notified. If notification was not requested explicitly, set to -1",
                                enumValues: nil
                            ),
                            "recurrenceType": ParameterDefinition(
                                type: .string,
                                description: "How often the event repeats",
                                enumValues: ["none", "daily", "weekly", "monthly", "yearly"]
                            ),
                            "recurrenceInterval": ParameterDefinition(
                                type: .integer,
                                description: "Time interval in the units specified by recurrenceType between the occurrences of the event",
                                enumValues: nil
                            ),
                            "recurrenceEndDate": ParameterDefinition(
                                type: .string,
                                description: "Date from which the event repeats will stop (ISO8601)",
                                enumValues: nil
                            )
                        ],
                        required: ["title"],
                        additionalProperties: false
                    )
                )
            ),
            Tool(
                type: .function,
                function: Function(
                    description: "Update, delete, or mark an event complete. If this tool has to be used, but no events in form '(eventId) title - date - recurrence: recurrenceType' are present in the messages, call first getEvents with small verbal confirmation of this action in content field",
                    name: .modifyEvent,
                    parameters: FunctionParams(
                        type: .object,
                        properties: [
                            "eventId": ParameterDefinition(
                                type: .integer,
                                description: "Unique identifier of event. Provided in the messages in the event summaries of form: '(eventId) title - date - recurrence: recurrenceType'",
                                enumValues: nil
                            ),
                            "date": ParameterDefinition(
                                type: .string,
                                description: "Date for which modification action was requested. ISO8601",
                                enumValues: nil
                            ),
                            "action": ParameterDefinition(
                                type: .string,
                                description: "Action to perform. Can be lead from implicit hints from user message (e.g. 'I want to delete event on...', 'I want to complete event on...', etc.)",
                                enumValues: ["update", "delete", "toggleCompletion"]
                            ),
                            "applyForAllAfter": ParameterDefinition(
                                type: .boolean,
                                description: "Show whether to apply the action to all event's occurrences after the original date. Default false",
                                enumValues: nil
                            ),
                            "title": ParameterDefinition(
                                type: .string,
                                description: "New title, if updating",
                                enumValues: nil
                            ),
                            "startDate": ParameterDefinition(
                                type: .string,
                                description: "New start date/time (ISO8601), if updating",
                                enumValues: nil
                            ),
                            "endDate": ParameterDefinition(
                                type: .string,
                                description: "New end date/time (ISO8601), if updating",
                                enumValues: nil
                            ),
                            "notificationInterval": ParameterDefinition(
                                type: .integer,
                                description: "Notification interval in minutes, if updating",
                                enumValues: nil
                            ),
                            "recurrenceType": ParameterDefinition(
                                type: .string,
                                description: "Recurrence type (none, daily, weekly, monthly, yearly), if updating",
                                enumValues: ["none", "daily", "weekly", "monthly", "yearly"]
                            ),
                            "recurrenceInterval": ParameterDefinition(
                                type: .integer,
                                description: "Recurrence interval (Time interval in the units specified by recurrenceType between the occurrences of the event), if updating",
                                enumValues: nil
                            )
                        ],
                        required: ["eventId", "action"],
                        additionalProperties: false
                    )
                )
            )
        ]
    }
}

struct ChatRequest: Codable {
    let model: String          // If the API still requires the model name.
    let messages: [ChatMessage]
    let temperature: Double?
    let tools: [Tool]?
    let tool_choice: ToolChoice?
}

enum ToolChoice: String, Codable {
    case none
    case auto
    case required
}

struct ChatMessage: Codable {
    let role: MessageRole
    /// `name` is optional but can be used when role is "tool message" or "function".
    let name: String?
    let content: String
    let tool_calls: [ToolCall]?
    let tool_call_id: String?
    let prefix: Bool?
    
    init(role: MessageRole, content: String, name: String? = nil, toll_calls: [ToolCall]? = nil, tool_call_id: String? = nil, prefix: Bool? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.tool_calls = toll_calls
        self.tool_call_id = tool_call_id
        self.prefix = prefix
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
}


struct ParameterDefinition: Codable {
    let type: ParameterType
    let description: String
    let enumValues: [String]?  // For enum types

    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }
}

enum ParameterType: String, Codable {
    case string
    case integer
    case boolean
    case object
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
    /// The chain-of-thought or reasoning text (if exposed by the model).
    let reasoning_content: String?
    /// The role of this message, typically "assistant".
    let role: String
    /// Any tool calls the assistant decided to make (if `finish_reason` = "tool_calls").
    let tool_calls: [ToolCall]?
}

/// A record of a single tool call invoked by the model.
struct ToolCall: Codable {
    /// A unique ID for this tool call.
    let id: String
    /// Currently only "function" is supported by the API.
    let type: String
    /// The function the model called.
    let function: ToolFunction
}

/// A function call invoked by the model/tool call.
struct ToolFunction: Codable {
    /// The name of the function the model decided to call.
    let name: String
    /// The arguments the model passed to that function.
    /// The model might return these as JSON (e.g. `"{\"param\":\"value\"}"`).
    let arguments: String
}

struct EmotionRecognitionResponse: Decodable {
    let pleasure: Double
    let arousal: Double
    let dominance: Double
    let label: String
}
