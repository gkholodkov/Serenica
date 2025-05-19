import Foundation

protocol AIServiceProtocol {
    /// A common system message that is shared by all implementations to generate NLP response.
    var systemMessage: ChatMessage { get }
    
    /// A common emotion and sentiment recognition prompt shared by all implementations
    var emotionRecognitionMessage: ChatMessage { get }
    
    /// A common JSON schema for emotion and sentiment recognition using LLM
    var emotionSchema: JSONSchema { get }
    
    /// A comon factual knowledge extraction prompt shared by all implementations
    var factExtractionMessage: ChatMessage { get }
    
    /// A common fact extraction tool function, which takes existing fact keys as argument
    func factExtractionTool(facts: [String]) -> Tool
        
    /// A common toolset that is shared by all implementations
    var tools: [Tool] { get }
    
    /// Sends a chat request
    func getNaturalLanguageResponse(newOrderedMessages: [ChatMessage], shortTermMemory: [ChatMessage]?, longTermMemory: ChatMessage?) async throws -> [Choice]
    
    func getToolCallsResponse(newOrderedMessages: [ChatMessage], shortTermMemory: [ChatMessage]?) async throws -> [ToolCall]
    
    func getEmotionRecognitionResponse(_ message: String) async throws -> EmotionRecognitionResponse
    
    func getFactExtractionResponse(_ message: String, factContext: [String], messageHistory: [ChatMessage]?) async throws -> [Fact]
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
            You are a warm, empathetic mental health awareness supporter. Always reply clearly and naturally in the user's language if available; if not, reply in English and kindly inform the user that their language isn't supported yet. Be attentive to signs of ADHD, ASD, and MDD. Use the user’s own self-descriptions and context from Memory Summary and message history to offer practical coping tips, encouragement, and relevant details—if appropriate. For severe concerns (such as suicidal thoughts, self-harm, or psychosis), remind the user that you’re not a substitute for professional help, and recommend crisis resources (Telefonseelsorge: 0800 111 0 111/0 222 for most cases, Nummer gegen Kummer: 0800 111 0 550 for parents regarding their children). Match your tone, phrasing, and empathy to the user's personality, emotional state, and situation. Keep responses concise (preferably under 120 characters, but it's a recommendation, not a restriction; allow longer responses if needed for crisis or support situations). If a user indirectly expresses stress or difficulty, offer empathy and gently try to make user speak out their struggles. Use facts, emotions, and personality knowldge from Memory Summary to address user's messages
            """
        )
    }
    
    var emotionRecognitionMessage: ChatMessage {
        ChatMessage(
            role: .system,
            content: """
            You're an emotion analyzer using PAD (Pleasure, Arousal, Dominance) model.
            """
        )
    }
    
    var emotionSchema: JSONSchema {
        JSONSchema(
            type: .object,
            properties: [
                "pleasure": JSONSchemaProperty(
                    type: .number,
                    description: "Pleasure level of the emotion expressed in user message as numeric score on a scale from -1.0 (absolutely negative) to 1.0 (absolutely positive)",
                    enumValues: nil
                ),
                "arousal": JSONSchemaProperty(
                    type: .number,
                    description: "Arousal level of the emotion expressed in user message as numeric score on a scale from -1.0 (absolutely not intense) to 1.0 (absolutely intense)",
                    enumValues: nil
                ),
                "dominance": JSONSchemaProperty(
                    type: .number,
                    description: "Dominance level of the emotion expressed in user message as numeric score on a scale from -1.0 (absolutely out of control with this emotion) to 1.0 (absolutely dominant with this emotion)",
                    enumValues: nil
                ),
                "label": JSONSchemaProperty(
                    type: .string,
                    description: "Name of the emotion expressed in the user message",
                    enumValues: [
                        "elation",
                        "exhilaration",
                        "wonder",
                        "pride",
                        "joy",
                        "amusement",
                        "confidence",
                        "contentment",
                        "serenity",
                        "vigilance",
                        "surprise",
                        "startle",
                        "interest",
                        "neutrality",
                        "reflection",
                        "composure",
                        "relaxation",
                        "boredom",
                        "rage",
                        "anger",
                        "fear",
                        "contempt",
                        "disgust",
                        "guilt",
                        "regret",
                        "sadness",
                        "despair"
                    ]
                )
            ],
            required: ["pleasure", "arousal", "dominance", "label"],
            additionalProperties: false
        )
    }
    
    var factExtractionMessage: ChatMessage {
        ChatMessage(
            role: .system,
            content: """
            You are a fact extractor. Analyze the following user message and output tool calls using the function \"updateKnowledge\". For each distinct fact identified, output a separate call with \"factKey\" and \"factValue\". If no new fact is detected, return an empty call. You are tasked with analyzing the following user message and any provided context to extract new factual information about the user. Focus on any information about user which might be useful to know long-term for someone who wants to be empathetic towards them. Only use call if some long-term relevant information, which means that such fact can be relevant for some remarkable period of life
            """
        )
    }
    
    func factExtractionTool(facts: [String]) -> Tool {
        // Generate a description that informs the LLM of the fact keys already in memory.
        let existingKeysDescription = facts.isEmpty ? "nothing" : facts.joined(separator: "\n")
        let descriptionText = """
        Extract new factual information about the user. Factual information consists of factKey (concise label for the entity of new fact, e.g. "hobbies", "home location", "relationship to parents", "mental state", etc.), and factValue (the corresponding details extracted from the user's message, e.g. "user has very poor relationships with their mother", or "user faces issues with different sex people", etc.). Here are the currently available facts collected in the memory: \(existingKeysDescription). Use this information to update the user's knowledge base for already existing keys, or new keys, if appropriate. Always proritize to mark more crucial and emotionally important pieces of information (death of close relatives, sever mental states, etc.).
        """
        
        return Tool(
            type: .function,
            function: Function(
                description: descriptionText,
                name: .updateKnowledge,
                parameters: FunctionParams(
                    type: .object,
                    properties: [
                        "factKey": ParameterDefinition(
                            type: .string,
                            description: "A short identifier for the type of fact (e.g., 'hobbies', 'relationships to strangers', etc.). If any key from the list in the context is semantically acceptable, reuse it",
                            enumValues: nil,
                            minimum: nil,
                            maximum: nil
                        ),
                        "factValue": ParameterDefinition(
                            type: .string,
                            description: "The actual information or detail for the fact",
                            enumValues: nil,
                            minimum: nil,
                            maximum: nil
                        ),
                        "timeToLive": ParameterDefinition(
                            type: .integer,
                            description: "Number of days for which the piece of information might be valuable and relevant. If piece of information is absolutely irrelevant long-term, return 0. If information is so relevant that it wold make sense to keep it as long as possible (e.g. if user shares the death of some important person), return null",
                            enumValues: nil,
                            minimum: 0,
                            maximum: nil
                        ),
                        "importance": ParameterDefinition(
                            type: .integer,
                            description: "Estimation of the importance of the fact from 1 (not important at all) to 10 (extremely improtant). Should be correlated with timeToLive (the higher timeToLive, the more important, and importance of 9 to 10 should have timeToLive equal null)",
                            enumValues: nil,
                            minimum: 0,
                            maximum: 10)
                    ],
                    required: ["factKey", "factValue", "timeToLive", "importance"],
                    additionalProperties: false
                )
            )
        )
    }
    
    var tools: [Tool] {
        [
            Tool(
                type: .function,
                function: Function(
                    description: "Fetch events by date range, specific dates, or title query.",
                    name: .getEvents,
                    parameters: FunctionParams(
                        type: .object,
                        properties: [
                            "dateFrom": ParameterDefinition(
                                type: .string,
                                description: "Start of the date range (ISO 8601 yyyy-MM-dd).",
                                enumValues: nil, minimum: nil, maximum: nil
                            ),
                            "dateTo": ParameterDefinition(
                                type: .string,
                                description: "End of the date range (ISO 8601 yyyy-MM-dd).",
                                enumValues: nil, minimum: nil, maximum: nil
                            ),
                            "specificDates": ParameterDefinition(
                                type: .array,
                                description: "An array of individual dates (ISO 8601 yyyy-MM-dd) to include.",
                                enumValues: nil, minimum: nil, maximum: nil
                            ),
                            "titleQuery": ParameterDefinition(
                                type: .string,
                                description: "Part of the event title to search",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
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
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "startDate": ParameterDefinition(
                                type: .string,
                                description: "Event start (ISO8601, format: yyyy-MM-dd'T'HH:mm:ss)",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "endDate": ParameterDefinition(
                                type: .string,
                                description: "Event end (ISO8601, format: yyyy-MM-dd'T'HH:mm:ss)",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "notificationInterval": ParameterDefinition(
                                type: .integer,
                                description: "Number of minutes before the event start user wants to be notified. If notification was not requested explicitly, set to -1",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "recurrenceType": ParameterDefinition(
                                type: .string,
                                description: "How often the event repeats",
                                enumValues: ["none", "daily", "weekly", "monthly", "yearly"],
                                minimum: nil,
                                maximum: nil
                            ),
                            "recurrenceInterval": ParameterDefinition(
                                type: .integer,
                                description: "Time interval in the units specified by recurrenceType between the occurrences of the event",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "recurrenceEndDate": ParameterDefinition(
                                type: .string,
                                description: "Date from which the event repeats will stop (ISO8601, format: yyyy-MM-dd'T'HH:mm:ss). This date should always be not earlier than endDate",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "notes": ParameterDefinition(
                                type: .string,
                                description: "Any additional details regarding the event, which might be useful to remember (place, conditions, preparations details, etc.)",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
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
                    description: "Update, delete, or mark an event complete. You may specify:\n1)eventId – if you already know the unique number of the event from the context, or\n2)originalTitle and/or date – in which case I will first fetch matching events automatically, then apply your requested action.",
                    name: .modifyEvent,
                    parameters: FunctionParams(
                        type: .object,
                        properties: [
                            "eventId": ParameterDefinition(
                                type: .integer,
                                description: "Unique identifier of event. Provided in the messages in the event summaries of form: '(eventId) title - date - recurrence: recurrenceType'. If you have such summaries, and user appeals to any event from there using indirect hints (pointing to the number, date, title, completion, or recurrence), choose the corresponding eventId from the parenthesses",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "originalTitle": ParameterDefinition(
                                type: .string,
                                description: "Full or partial event title to search for before modifying.",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "originalDate": ParameterDefinition(
                                type: .string,
                                description: "Original date of the event or the occurence for which modification action was requested (ISO8601, format: yyyy-MM-dd).",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "action": ParameterDefinition(
                                type: .string,
                                description: "Action to perform. Can be lead from implicit hints from user message (e.g. 'I want to delete event on...', 'I want to complete event on...', etc.)",
                                enumValues: ["update", "delete", "toggleCompletion"],
                                minimum: nil,
                                maximum: nil
                            ),
                            "applyForAllAfter": ParameterDefinition(
                                type: .boolean,
                                description: "Show whether to apply the action to all event's occurrences after the original date. Default false",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "newTitle": ParameterDefinition(
                                type: .string,
                                description: "New title, if updating",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "newStartDate": ParameterDefinition(
                                type: .string,
                                description: "New start date/time (ISO8601, format: yyyy-MM-dd'T'HH:mm:ss), if updating. If user asked to remove it, just set it empty string",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "newEndDate": ParameterDefinition(
                                type: .string,
                                description: "New end date/time (ISO8601, format: yyyy-MM-dd'T'HH:mm:ss), if updating. If user asked to remove it, just set it empty string. Also, set it empty string if user asked to remove start date only",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "newNotificationInterval": ParameterDefinition(
                                type: .integer,
                                description: "Notification interval in minutes, if updating",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            ),
                            "newRecurrenceType": ParameterDefinition(
                                type: .string,
                                description: "Recurrence type (none, daily, weekly, monthly, yearly), if updating",
                                enumValues: ["none", "daily", "weekly", "monthly", "yearly"],
                                minimum: nil,
                                maximum: nil
                            ),
                            "newRecurrenceInterval": ParameterDefinition(
                                type: .integer,
                                description: "Recurrence interval (Time interval in the units specified by recurrenceType between the occurrences of the event), if updating",
                                enumValues: nil,
                                minimum: nil,
                                maximum: nil
                            )
                        ],
                        required: ["action"],
                        additionalProperties: false
                    )
                )
            )
        ]
    }
}
