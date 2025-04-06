import Foundation

class AIEventAgent {
    let authService: AuthService
    let memoryService: AgentMemoryServiceProtocol
    let aiService: AIServiceProtocol
    let emotionRecognitionService: EmotionRecognitionService
    let eventService: EventService
    let eventContextManager: EventContextManager
    
    init(authService: AuthService, memoryService: AgentMemoryServiceProtocol, aiService: AIServiceProtocol, emotionRecognitionService: EmotionRecognitionService, eventService: EventService, eventContextManager: EventContextManager) {
        self.memoryService = memoryService
        self.aiService = aiService
        self.eventService = eventService
        self.eventContextManager = eventContextManager
        self.emotionRecognitionService = emotionRecognitionService
        self.authService = authService
    }
    
    func handleUserMessage(_ message: String, completion: @escaping (String) -> Void) async {
        do {
            let userContext = memoryService.fetchLongTermMemory() ?? ""
            let longTermMemoryKnowledge = userContext.isEmpty ? nil : ChatMessage(role: .assistant, content: userContext)
            let shortTermMemoryToolMessages = memoryService.fetchShortTermToolsMemory()
            var newShortTermMemoryToolKnowledge: [ChatMessage] = []
            let shortTermMemoryChatMessages = memoryService.fetchShortTermChatMemory()
            var newShortTermMemoryChatKnowledge: [ChatMessage] = []
            
            let toolsCalls = try await aiService.getToolCallsResponse(message, shortTermMemory: shortTermMemoryToolMessages)
            
            let toolCallResultChatMessages = await handleToolCalls(toolsCalls)
            
            if (!toolsCalls.isEmpty && !toolCallResultChatMessages.isEmpty) {
                newShortTermMemoryToolKnowledge.append(ChatMessage(role: .user, content: message))
                newShortTermMemoryToolKnowledge.append(ChatMessage(role: .assistant, content: "", toll_calls: toolsCalls))
                newShortTermMemoryToolKnowledge.append(contentsOf: toolCallResultChatMessages)
            }
            
            let prefixMessage = toolCallResultChatMessages.count > 1 ? ChatMessage(role: .assistant, content: toolCallResultChatMessages[1].content, prefix: true) : nil
            let nlpResponse = try await aiService.getNaturalLanguageResponse(message, prefixMessage: prefixMessage, shortTermMemory: shortTermMemoryChatMessages, longTermMemory: longTermMemoryKnowledge)
            
            newShortTermMemoryChatKnowledge.insert(ChatMessage(role: .user, content: message), at: 0)
            newShortTermMemoryChatKnowledge.append(ChatMessage(role: .assistant, content: nlpResponse.first?.message.content ?? ""))
            
            memoryService.changeShortTermChatMemory(newShortTermMemoryChatKnowledge)
            memoryService.changeShortTermToolsMemory(newShortTermMemoryToolKnowledge)
            
            Task {
                do {
                    let emotionalState = memoryService.fetchLongTermMemoryEmotions()
                    let newEmotion = try await emotionRecognitionService.analyzeEmotionHybrid(message, previousEmotion: emotionalState.averageEmotion())
                    memoryService.changeLongTermMemory(newEmotion: newEmotion, newFacts: nil, newPersonalityProfile: nil)
                } catch {}
            }
            
            completion(nlpResponse.first?.message.content ?? "")
        } catch {
            completion("Sorry, a technical error occurred. Please try again.")
        }
    }
    
    private func handleToolCalls(_ toolCalls: [ToolCall]) async -> [ChatMessage] {
        let formatter = ISO8601DateFormatter()
        
        for toolCall in toolCalls {
            switch toolCall.function.name {
            case "createEvent":
                guard let argsData = toolCall.function.arguments.data(using: .utf8),
                      authService.currentUser != nil else {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for createEvent.\"", name: "createEvent", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "Some errors happened during the formatting of your request.")
                    return [functionResponseMessage, errorChatMessage]
                }
                do {
                    let decodedArgs = try JSONDecoder().decode(CreateEventArgs.self, from: argsData)
                    
                    // Since title is required in the new args, we check if it's empty.
                    if decodedArgs.title.isEmpty {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Missing required field: date.\"", name: "createEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "You haven't provided me with a title of the event you want to create.")
                        return [functionResponseMessage, errorChatMessage]
                    }
                    
                    // Create the event with the new properties.
                    let event = Event(
                        id: UUID(),
                        title: decodedArgs.title,
                        startDate: formatter.date(from: decodedArgs.startDate ?? ""),
                        endDate: formatter.date(from: decodedArgs.endDate ?? ""),
                        notes: "", // No notes in the new args.
                        userId: authService.currentUser!.id,
                        notificationId: (decodedArgs.notificationInterval != nil && decodedArgs.notificationInterval != -1) ? UUID() : nil,
                        notificationInterval: decodedArgs.notificationInterval != nil ? Double(decodedArgs.notificationInterval!) : nil,
                        recurrenceType: {
                            if let recurrenceTypeStr = decodedArgs.recurrenceType,
                               let type = RecurrenceType.fromString(recurrenceTypeStr) {
                                return type
                            }
                            return .none
                        }(),
                        recurrenceInterval: decodedArgs.recurrenceInterval ?? 0,
                        recurrenceEndDate: formatter.date(from: decodedArgs.recurrenceEndDate ?? "")
                    )
                    
                    eventService.addEvent(event)
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event created successfully.\"", name: "createEvent", tool_call_id: toolCall.id)
                    let explanationChatMessage = ChatMessage(role: .assistant, content: "Event was created successfully.")
                    return [functionResponseMessage, explanationChatMessage]
                } catch {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for createEvent: \(error.localizedDescription).\"", name: "getEvents", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "Couldn't parse the arguments from your request.")
                    return [functionResponseMessage, errorChatMessage]
                }
                
            case "modifyEvent":
                guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for modifyEvent.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "Some errors happened during the formatting of your request.")
                    return [functionResponseMessage, errorChatMessage]
                }
                do {
                    let modifyArgs = try JSONDecoder().decode(ModifyEventArgs.self, from: argsData)
                    
                    guard let uuid = await eventContextManager.uuid(forTemporaryId: modifyArgs.eventId) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid UUID for event context manager.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "I couldn't find the event you want to change.")
                        return [functionResponseMessage, errorChatMessage]
                    }
                        
                    let lookupDate = formatter.date(from: modifyArgs.date ?? "")
                    guard let event = eventService.getEvent(byId: uuid) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"No matching event found.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "I couldn't find the event you want to change.")
                        return [functionResponseMessage, errorChatMessage]
                    }
                    
                    switch modifyArgs.action {
                    case "update":
                        var updatedEvent = event
                        if let newTitle = modifyArgs.title, !newTitle.isEmpty {
                            updatedEvent.title = newTitle
                        }
                        if let newStartDateStr = modifyArgs.startDate, let newStartDate = formatter.date(from: newStartDateStr) {
                            updatedEvent.startDate = newStartDate
                        }
                        if let newEndDateStr = modifyArgs.endDate, let newEndDate = formatter.date(from: newEndDateStr) {
                            updatedEvent.endDate = newEndDate
                        }
                        if let newNotificationInterval = modifyArgs.notificationInterval {
                            if newNotificationInterval == -1 {
                                updatedEvent.notificationId = nil
                            } else {
                                updatedEvent.notificationInterval = Double(newNotificationInterval)
                                if updatedEvent.notificationId == nil {
                                    updatedEvent.notificationId = UUID()
                                }
                            }
                        }
                        var changedRecurrence = false
                        if let newRecurrenceTypeStr = modifyArgs.recurrenceType,
                            let recurrenceType = RecurrenceType.fromString(newRecurrenceTypeStr) {
                            updatedEvent.recurrenceType = recurrenceType
                            changedRecurrence = true
                        }
                        if let newRecurrenceInterval = modifyArgs.recurrenceInterval {
                            updatedEvent.recurrenceInterval = newRecurrenceInterval
                            changedRecurrence = true
                        }
                        
                        // For recurring events, decide whether to apply changes for all future occurrences.
                        if (modifyArgs.applyForAllAfter == true || changedRecurrence) && updatedEvent.recurrenceType != .none {
                            eventService.updateAllFutureOccurrences(of: event, on: lookupDate ?? Date(), with: updatedEvent)
                        } else if updatedEvent.recurrenceType != .none {
                            eventService.updateSingleOccurrence(of: event, on: lookupDate ?? Date(), with: updatedEvent)
                        } else {
                            eventService.updateEvent(updatedEvent, initialNotificationId: event.notificationId)
                        }
                        
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event updated successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let explanationChatMessage = ChatMessage(role: .assistant, content: "I've successfully updated your event with title \"\(event.title)\".")
                        return [functionResponseMessage, explanationChatMessage]
                    case "delete":
                        if modifyArgs.applyForAllAfter == true && event.recurrenceType != .none {
                            eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                        } else if event.recurrenceType != .none {
                            eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                        } else {
                            eventService.deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
                        }
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event deleted successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let explanationChatMessage = ChatMessage(role: .assistant, content: "I've successfully deleted your event with title \"\(event.title)\".")
                        return [functionResponseMessage, explanationChatMessage]
                    case "toggleCompletion":
                        eventService.toggleEventCompletion(event, on: lookupDate ?? Date())
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event completion toggled successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let explanationChatMessage = ChatMessage(role: .assistant, content: "I've successfully completed your event with title \"\(event.title)\".")
                        return [functionResponseMessage, explanationChatMessage]
                        
                    default:
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Unhandled action: \(modifyArgs.action).\"", name: toolCall.function.name, tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "Sorry, I can't support you with that.")
                        return [functionResponseMessage, errorChatMessage]
                    }
                } catch {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for modifyEvent: \(error.localizedDescription).\"", name: "getEvents", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "Sorry, I couldn't parse the arguments from your request.")
                    return [functionResponseMessage, errorChatMessage]
                }
                
            case "getEvents":
                guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for getEvents.\"", name: "getEvents", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "Some errors happened during the formatting of your request.")
                    return [functionResponseMessage, errorChatMessage]
                }
                do {
                    let getEventsArgs = try JSONDecoder().decode(GetEventsArgs.self, from: argsData)
                    let lookupDate = formatter.date(from: getEventsArgs.date ?? "")
                    let events = eventService.getEvents(byDate: lookupDate, byTitle: getEventsArgs.titleQuery)
                    await eventContextManager.setEventsCacheAndIdMap(events)
                    let summaries = await eventContextManager.getCurrentEventCacheKnowledge() ?? ""
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"summaries\": \"\(summaries))\"", name: "getEvents", tool_call_id: toolCall.id)
                    let explanationChatMessage = summaries.isEmpty ? ChatMessage(role: .assistant, content: "I haven't found any events matching your request.") : ChatMessage(role: .assistant, content: "Here're the events I found for your request:\n \(summaries)\n\n")
                    return [functionResponseMessage, explanationChatMessage]
                } catch {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for getEvents: \(error.localizedDescription).\"", name: "getEvents", tool_call_id: toolCall.id)
                    let responseChatMessage = ChatMessage(role: .assistant, content: "Sorry, I couldn't parse the arguments from your request.")
                    return [functionResponseMessage, responseChatMessage]
                }
                    
            default:
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Unhandled function: \(toolCall.function.name).\"", name: toolCall.function.name, tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "Sorry, I can't support you with that.")
                return [functionResponseMessage, errorChatMessage]
            }
        }
        
        return []
    }
}
