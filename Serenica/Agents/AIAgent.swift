import Foundation

class AIAppAgent {
    private var authService: AuthService
    let memoryService: AgentMemoryService
    let aiService: AIServiceProtocol
    let emotionRecognitionService: EmotionRecognitionService
    let factExtractionService: FactExtractionService
    let personalityCreationService: PersonalityCreationService
    let eventService: EventService
    let eventContextManager: EventContextManager
    
    private let endDebouncer = Debouncer(delay: 5 * 60)
    
    init(authService: AuthService, memoryService: AgentMemoryService, aiService: AIServiceProtocol, emotionRecognitionService: EmotionRecognitionService, factExtractionService: FactExtractionService, personalityCreationService: PersonalityCreationService, eventService: EventService, eventContextManager: EventContextManager) {
        self.memoryService = memoryService
        self.aiService = aiService
        self.eventService = eventService
        self.eventContextManager = eventContextManager
        self.emotionRecognitionService = emotionRecognitionService
        self.factExtractionService = factExtractionService
        self.personalityCreationService = personalityCreationService
        self.authService = authService
    }
    
    // MARK: - Dependency Updates
    
    /// Call this to update the auth service (for example, when the user signs in or out).
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
        memoryService.updateAuthService(newAuthService)
        eventService.updateAuthService(newAuthService)
    }
    
    func handleUserMessage(_ message: String, completion: @escaping (String) -> Void) async {
        do {
            resetEndTimer()
            let userContext = memoryService.fetchLongTermMemoryDescription() ?? ""
            let longTermMemoryKnowledge = userContext.isEmpty ? nil : ChatMessage(role: .assistant, content: userContext)
            let shortTermMemoryToolMessages = memoryService.fetchShortTermToolsMemory()
            let shortTermMemoryChatMessages = memoryService.fetchShortTermChatMemory()
            var newShortTermMemoryKnowledge: [ChatMessage] = [ChatMessage(role: .user, content: message)]
            
            let toolsCalls = try await aiService.getToolCallsResponse(message, shortTermMemory: shortTermMemoryToolMessages)
            print(toolsCalls)
            
            var acumulatedToolCallExplanation: String = ""
            
            for (index, toolCall) in toolsCalls.enumerated() {
                print("Tool call: \(toolCall)")
                let toolCallResultChatMessages = await handleToolCalls(toolCall)
                
                newShortTermMemoryKnowledge.append(ChatMessage(role: .assistant, content: "", tool_calls: [toolCall]))
                newShortTermMemoryKnowledge.append(toolCallResultChatMessages.toolMessage)
                acumulatedToolCallExplanation += "\(toolCallResultChatMessages.explanationMessage.content)"
                if (index < toolsCalls.count - 1) {
                    acumulatedToolCallExplanation += "\n"
                }
            }
            
            let prefixMessage = acumulatedToolCallExplanation.isEmpty ? nil : ChatMessage(role: .assistant, content: acumulatedToolCallExplanation, prefix: true)
            let nlpResponse = try await aiService.getNaturalLanguageResponse(message, prefixMessage: prefixMessage, shortTermMemory: shortTermMemoryChatMessages, longTermMemory: longTermMemoryKnowledge)
            
            newShortTermMemoryKnowledge.append(ChatMessage(role: .assistant, content: nlpResponse.first?.message.content ?? ""))
            
            memoryService.changeShortTermMemory(newShortTermMemoryKnowledge)
            
            Task {
                do {
                    let memory = memoryService.fetchLongTermMemory()
                    let newEmotion = try await emotionRecognitionService.analyzeEmotionHybrid(message, previousEmotion: memory.emotionalState.averageEmotion())
                    let newPersonalityProfile = personalityCreationService.derivePersonality(from: memory.personality, usingEmotions: memory.emotionalState + [newEmotion])
                    print("New Emotion: \(newEmotion)")
                    print("New Personality Profile: \(newPersonalityProfile)")
                    await memoryService.changeLongTermMemory(newEmotion: newEmotion, newFacts: nil, newPersonalityProfile: newPersonalityProfile)
                } catch {}
            }
            
            completion(nlpResponse.first?.message.content ?? "")
        } catch {
            completion("I’m really sorry—something unexpected came up on my end. Would you mind trying again? Or, if it happens multiple times already, could you please contact customer support team?")
        }
    }
    
    private func handleToolCalls(_ toolCall: ToolCall) async -> (toolMessage: ChatMessage, explanationMessage: ChatMessage) {
        switch toolCall.function.name {
        case "createEvent":
            guard let argsData = toolCall.function.arguments.data(using: .utf8),
                  authService.currentUser != nil else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for createEvent.\"", name: "createEvent", tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "I'm sorry, something went wrong while processing your event. Could you please try again, or contact customer support team, if it happens repeatedly?")
                
                return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
            }
            do {
                let decodedArgs = try JSONDecoder().decode(CreateEventArgs.self, from: argsData)
                
                // Since title is required in the new args, we check if it's empty.
                if decodedArgs.title.isEmpty {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Missing required field: title.\"", name: "createEvent", tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "I didn't catch an event title. Could you please let me know what it should be?")
                    
                    return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                }
                var finalStart: Date? = nil
                var finalEnd: Date? = nil
                var finalRecurrenceEnd: Date? = nil
                
                let startRaw = decodedArgs.startDate ?? ""
                let endRaw = decodedArgs.endDate ?? ""
                let recurRaw = decodedArgs.recurrenceEndDate ?? ""

                let parsedStartDate: Date? = {
                    guard !startRaw.isEmpty else { return nil }
                    return DateFormatter.localDateTimeFormatter.date(from: startRaw)
                }()
                
                let parsedEndDate: Date? = {
                    guard !endRaw.isEmpty else { return nil }
                    return DateFormatter.localDateTimeFormatter.date(from: endRaw)
                }()
                
                let parsedRecurrenceEnd: Date? = {
                    guard !recurRaw.isEmpty else { return nil }
                    return DateFormatter.localDateTimeFormatter.date(from: recurRaw)
                }()

                
                let baseStart = parsedStartDate ?? parsedEndDate?.addingTimeInterval(-3600)
                let baseEnd = parsedEndDate ?? parsedStartDate?.addingTimeInterval(3600)

                let now = Date()
                if baseStart != nil && baseEnd != nil {
                    finalStart = baseStart! < now ? now.addingTimeInterval(60) : baseStart!
                    finalEnd = baseEnd! < finalStart! ? finalStart!.addingTimeInterval(3600) : baseEnd!

                    finalRecurrenceEnd = parsedRecurrenceEnd
                    if let recur = parsedRecurrenceEnd, recur <= finalEnd! {
                        finalRecurrenceEnd = finalEnd!.addingTimeInterval(3600)
                    }
                }
                
                // Create the event with the new properties.
                let event = Event(
                    id: UUID(),
                    title: decodedArgs.title,
                    startDate: finalStart,
                    endDate: finalEnd,
                    notes: "",
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
                    recurrenceEndDate: finalRecurrenceEnd
                )
                
                eventService.addEvent(event)
                
                let startDateString = event.startDate != nil ? "\(DateFormatter.germanLongDate.string(from: event.startDate!)) \(DateFormatter.germanShortTime.string(from: event.startDate!))" : ""
                let endDateString = event.endDate != nil ? "\(DateFormatter.germanLongDate.string(from: event.endDate!)) \(DateFormatter.germanShortTime.string(from: event.endDate!))" : ""
                                
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event created successfully.\"", name: "createEvent", tool_call_id: toolCall.id)
                let explanationChatMessage = ChatMessage(role: .assistant, content: "I've scheduled your \"\(event.title)\" event \(event.startDate != nil && event.endDate != nil ? "from \(startDateString) to \(endDateString)" : "and added it to an Unassigned folder"). I hope it gives you a little time to care for yourself.")
                
                return (toolMessage: functionResponseMessage, explanationMessage: explanationChatMessage)
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for createEvent: \(error.localizedDescription).\"", name: "getEvents", tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "I couldn't understand your event details. Could you please check and try again? Also, if it happens repeatedly, could you please inform our customer support about that?")
                
                return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
            }
            
        case "modifyEvent":
            guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for modifyEvent.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "I encountered an error while processing your event. Could you please try again?")
                
                return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
            }
            do {
                let modifyArgs = try JSONDecoder().decode(ModifyEventArgs.self, from: argsData)
                let lookupDate = DateFormatter.localDateFormatter.date(from: modifyArgs.date ?? "")
                var event: Event
                
                if let eventId = modifyArgs.eventId {
                    guard let uuid = await eventContextManager.uuid(forTemporaryId: eventId) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid UUID for event context manager.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "I couldn't locate the event you'd like to change in my memory. Could you share some specific details about it?")
                        
                        return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                    }
                    guard let potentialEvent = eventService.getEvent(byId: uuid) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"No matching event found.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "It seems like I memorized event incorrectly, I'm sorry about that. Could you please share some specific details about it, so that I could search for it?")
                        
                        return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                    }
                    event = potentialEvent
                } else {
                    let events = eventService.getEvents(byDates: lookupDate != nil ? [lookupDate!] : nil, byTitle: modifyArgs.originalTitle)
                    let dateSearchDetails = lookupDate != nil ? " around the \(DateFormatter.germanLongDate.string(from: lookupDate!))" : ""
                    let titleSearchDetails = modifyArgs.originalTitle != nil ? " with \"\(modifyArgs.originalTitle!)\" title" : ""
                    
                    if events.isEmpty {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"No matching event found.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "Sorry, I've searched for events\(dateSearchDetails)\(titleSearchDetails) as you asked, however, I couldn't find anything. Could you double check some details?")
                        
                        return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                    } else if events.count > 1 {
                        await eventContextManager.setEventsCacheAndIdMap(events)
                        let summaries = await eventContextManager.getCurrentEventCacheKnowledge() ?? ""
                        let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Multiple events found.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                        let errorChatMessage = ChatMessage(role: .assistant, content: "I've found these events\(dateSearchDetails)\(titleSearchDetails) in your calendar:\n \(summaries)\n\n")
                        
                        return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                    } else {
                        event = events[0]
                    }
                }
                
                switch modifyArgs.action {
                case "update":
                    var updatedEvent = event
                    let now = Date()
                    if let newTitle = modifyArgs.title, !newTitle.isEmpty {
                        updatedEvent.title = newTitle
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
                    
                    // 1) Try parsing each incoming string (nil or empty → nil Date)
                    let parsedStartDate: Date? = {
                        guard let s = modifyArgs.startDate, !s.isEmpty else { return nil }
                        return DateFormatter.localDateTimeFormatter.date(from: s)
                    }()

                    let parsedEndDate: Date? = {
                        guard let s = modifyArgs.endDate, !s.isEmpty else { return nil }
                        return DateFormatter.localDateTimeFormatter.date(from: s)
                    }()

                    // 2) If either was explicitly emptied, clear everything
                    if modifyArgs.startDate == "" || modifyArgs.endDate == "" {
                        updatedEvent.startDate = nil
                        updatedEvent.endDate = nil
                        updatedEvent.recurrenceType = .none
                        updatedEvent.recurrenceEndDate = nil
                        changedRecurrence = true

                    } else {
                        // 3) Assign any new parsed values
                        if let start = parsedStartDate {
                            updatedEvent.startDate = start
                        }
                        if let end = parsedEndDate {
                            updatedEvent.endDate = end
                        }

                        // 4) If only start changed, give end a default +1h
                        if parsedStartDate != nil && parsedEndDate == nil, let newStart = updatedEvent.startDate {
                            updatedEvent.endDate = newStart.addingTimeInterval(3600)
                        }

                        // 5) If only end changed, give start a default –1h
                        if parsedEndDate != nil && parsedStartDate == nil, let newEnd = updatedEvent.endDate {
                            updatedEvent.startDate = newEnd.addingTimeInterval(-3600)
                        }

                        // 6) Final sanity: ensure end ≥ start (else end = start +1h)
                        if let start = updatedEvent.startDate,
                           start < now {
                            updatedEvent.startDate = now.addingTimeInterval(60)
                        }
                        
                        if let start = updatedEvent.startDate,
                           let end = updatedEvent.endDate,
                           end < start
                        {
                            updatedEvent.endDate = start.addingTimeInterval(3600)
                        }
                        
                        if let end = updatedEvent.endDate, let recEnd = updatedEvent.recurrenceEndDate, end < recEnd {
                            updatedEvent.recurrenceEndDate = end.addingTimeInterval(3600)
                        }
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
                    
                    // For recurring events, decide whether to apply changes for all future occurrences.
                    if (modifyArgs.applyForAllAfter == true || changedRecurrence) && updatedEvent.recurrenceType != .none {
                        eventService.updateAllFutureOccurrences(of: event, on: lookupDate ?? Date(), with: updatedEvent)
                    } else if updatedEvent.recurrenceType != .none {
                        eventService.updateSingleOccurrence(of: event, on: lookupDate ?? Date(), with: updatedEvent)
                    } else {
                        eventService.updateEvent(updatedEvent, initialNotificationId: event.notificationId)
                    }
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event updated successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                    let explanationChatMessage = ChatMessage(role: .assistant, content: "I've gently updated your event \"\(event.title)\". I hope this adjustment helps you feel more in control.")
                    return (toolMessage: functionResponseMessage, explanationMessage: explanationChatMessage)
                case "delete":
                    if modifyArgs.applyForAllAfter == true && event.recurrenceType != .none {
                        eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                    } else if event.recurrenceType != .none {
                        eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                    } else {
                        eventService.deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
                    }
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event deleted successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                    let explanationChatMessage = ChatMessage(role: .assistant, content: "I've removed the event \"\(event.title)\". I hope this change gives you more space to breathe.")
                    return (toolMessage: functionResponseMessage, explanationMessage: explanationChatMessage)
                case "toggleCompletion":
                    eventService.toggleEventCompletion(event, on: lookupDate ?? Date())
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"result\": \"Event completion toggled successfully.\"", name: "modifyEvent", tool_call_id: toolCall.id)
                    let explanationChatMessage = ChatMessage(role: .assistant, content: "I've marked your event \"\(event.title)\" as completed. Well done on taking care of yourself.")
                    return (toolMessage: functionResponseMessage, explanationMessage: explanationChatMessage)
                    
                default:
                    let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Unhandled action: \(modifyArgs.action).\"", name: toolCall.function.name, tool_call_id: toolCall.id)
                    let errorChatMessage = ChatMessage(role: .assistant, content: "I'm sorry, I can't support that action right now.")
                    return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
                }
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for modifyEvent: \(error.localizedDescription).\"", name: toolCall.function.name, tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "I ran into some trouble understanding the details. Could you please check and try again, or contact our customer support, if it happened to you frequently?")
                return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
            }
            
        case "getEvents":
            guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Invalid arguments format was used for getEvents.\"", name: "getEvents", tool_call_id: toolCall.id)
                let errorChatMessage = ChatMessage(role: .assistant, content: "I encountered a hiccup while trying to fetch your events. Could you try again, or contact our customer support, if it annoys you?")
                return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
            }
            do {
                let getEventsArgs = try JSONDecoder().decode(GetEventsArgs.self, from: argsData)
                let dates = getEventsArgs.specificDates?.compactMap { DateFormatter.localDateFormatter.date(from: $0) } ?? Date.dateSpan(from: DateFormatter.localDateFormatter.date(from: getEventsArgs.dateFrom ?? ""), to: DateFormatter.localDateFormatter.date(from: getEventsArgs.dateTo ?? ""))
                
                let events = eventService.getEvents(byDates: dates, byTitle: getEventsArgs.titleQuery)
                await eventContextManager.setEventsCacheAndIdMap(events)
                let summaries = await eventContextManager.getCurrentEventCacheKnowledge() ?? ""
                
                let dateSearchDetails = dates.isEmpty
                    ? ""
                    : dates.count == 1
                      ? " on \(DateFormatter.germanLongDate.string(from: dates[0]))"
                      : " around the \(dates.map { DateFormatter.germanLongDate.string(from: $0) }.joined(separator: ", or "))"

                let titleSearchDetails = getEventsArgs.titleQuery != nil
                    ? " with \"\(getEventsArgs.titleQuery!)\" title"
                    : ""
                
                let explanationContent: String
                switch events.count {
                case 0:
                    explanationContent = "I couldn’t find any events\(dateSearchDetails)\(titleSearchDetails). Would you like help creating one?"
                case 1:
                    explanationContent = "Here’s the only event\(dateSearchDetails)\(titleSearchDetails) in your calendar: \(summaries)"
                default:
                    explanationContent = "I’ve found these events\(dateSearchDetails)\(titleSearchDetails) in your calendar:\n\(summaries)"
                }
                
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"summaries\": \"\(summaries))\"", name: "getEvents", tool_call_id: toolCall.id)
                let explanationChatMessage = ChatMessage(role: .assistant, content: explanationContent)
                return (toolMessage: functionResponseMessage, explanationMessage: explanationChatMessage)
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Failed to decode arguments for getEvents: \(error.localizedDescription).\"", name: "getEvents", tool_call_id: toolCall.id)
                let responseChatMessage = ChatMessage(role: .assistant, content: "I'm sorry, I couldn't understand the event details. Could you please check and try again? Or, if it happens repeatedly, please contact our customer support.")
                return (toolMessage: functionResponseMessage, explanationMessage: responseChatMessage)
            }
                
        default:
            let functionResponseMessage = ChatMessage(role: .tool, content: "\"error\": \"Unhandled function: \(toolCall.function.name).\"", name: toolCall.function.name, tool_call_id: toolCall.id)
            let errorChatMessage = ChatMessage(role: .assistant, content: "I'm sorry, I can't support that action right now.")
            return (toolMessage: functionResponseMessage, explanationMessage: errorChatMessage)
        }
    }

    /// Centralized “end of convo” entrypoint.
    func endConversation(reason: EndReason) async {
        endDebouncer.cancel()
        
        // Grab whatever chat you’ve collected so far:
        let memory = memoryService.fetchLongTermMemory()
        print(memory.knowledge)
        let messages = memoryService.fetchShortTermChatMemory()
        // Run your batch‑analysis (instead of per‑message):
        let newFacts = await factExtractionService.extractNewFacts(messages, knownFacts: memory.knowledge.enumerated().map { (index, fact) in "\(index + 1)) Key: \(fact.key); Value: \(fact.value)" })
        print("New facts: \(newFacts)")
        await memoryService.changeLongTermMemory(newEmotion: nil, newFacts: newFacts, newPersonalityProfile: nil)
        // Optionally: clear the short‑term memory buffer?
        // memoryService.clearShortTermMemory()
    }
    
    func refreshLastConversation(_ messages: [Message]) {
        if (memoryService.fetchShortTermChatMemory().isEmpty || memoryService.fetchShortTermToolsMemory().isEmpty) {
            memoryService.changeShortTermMemory(messages.map { message in ChatMessage(role: message.isFromUser ? .user : .assistant, content: message.content) })
        }
        print("Refreshed short term memory: \(memoryService.fetchShortTermChatMemory())")
    }
    
    func reset() {
        memoryService.clearMemory()
    }
    
    private func resetEndTimer() {
        endDebouncer.schedule { [weak self] in
            Task { await self?.endConversation(reason: .idleTimeout) }
        }
    }
}
