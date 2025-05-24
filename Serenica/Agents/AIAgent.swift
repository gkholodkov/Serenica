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
            let userContext = memoryService.fetchLongTermMemoryDescription() ?? ""
            let longTermMemoryKnowledge = userContext.isEmpty ? nil : ChatMessage(role: .assistant, content: userContext)
            let shortTermMemoryMessages = memoryService.fetchShortTermMemory()
            var newShortTermMemoryKnowledge: [ChatMessage] = [ChatMessage(role: .user, content: message)]
            
            let toolsCalls = try await aiService.getToolCallsResponse(newOrderedMessages: newShortTermMemoryKnowledge, shortTermMemory: shortTermMemoryMessages)
            
            if !toolsCalls.isEmpty {
                newShortTermMemoryKnowledge.append(ChatMessage(role: .assistant, content: "", tool_calls: toolsCalls))
                for toolCall in toolsCalls {
                    print("Tool call: \(toolCall)")
                    let toolCallResultChatMessage = await handleToolCall(toolCall)
                    
                    newShortTermMemoryKnowledge.append(toolCallResultChatMessage)
                }
            }
            
            let nlpResponse = try await aiService.getNaturalLanguageResponse(newOrderedMessages: newShortTermMemoryKnowledge, shortTermMemory: shortTermMemoryMessages, longTermMemory: longTermMemoryKnowledge)
            
            newShortTermMemoryKnowledge.append(ChatMessage(role: .assistant, content: nlpResponse.first?.message.content ?? ""))
            
            memoryService.changeShortTermMemory(newShortTermMemoryKnowledge)
            
            Task {
                do {
                    let memory = memoryService.fetchLongTermMemory()
                    let newEmotion = try await emotionRecognitionService.analyzeEmotionHybrid(message, previousEmotion: memory.emotionalState.averageEmotion())
                    let newPersonalityProfile = personalityCreationService.derivePersonality(from: memory.personality, usingEmotions: memory.emotionalState + [newEmotion])
                    await memoryService.changeLongTermMemory(newEmotion: newEmotion, newFacts: nil, newPersonalityProfile: newPersonalityProfile)
                } catch {}
            }
            
            completion(nlpResponse.first?.message.content ?? "")
        } catch {
            completion("I’m really sorry—something unexpected came up on my end. Would you mind trying again? Or, if it happens multiple times already, could you please contact customer support team?")
        }
    }
    
    private func handleToolCall(_ toolCall: ToolCall) async -> ChatMessage {
        switch toolCall.function.name {
        case "createEvent":
            guard let argsData = toolCall.function.arguments.data(using: .utf8),
                  authService.currentUser != nil else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Invalid arguments format was used for createEvent.\"}", name: "createEvent", tool_call_id: toolCall.id)
                
                return functionResponseMessage
            }
            do {
                let decodedArgs = try JSONDecoder().decode(CreateEventArgs.self, from: argsData)
                
                // Since title is required in the new args, we check if it's empty.
                if decodedArgs.title.isEmpty {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Missing required field: title.\"}", name: "createEvent", tool_call_id: toolCall.id)
                    
                    return functionResponseMessage
                }
                var finalStart: Date? = nil
                var finalEnd: Date? = nil
                var finalRecurrenceEnd: Date? = nil
                
                let startRaw = Date.sanitizeISODateTime(decodedArgs.startDate ?? "")
                let endRaw = Date.sanitizeISODateTime(decodedArgs.endDate ?? "")
                let recurRaw = Date.sanitizeISODateTime(decodedArgs.recurrenceEndDate ?? "")

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
                    notes: decodedArgs.notes ?? "",
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
                
                print("Agents adds event: \(event)")
                
                eventService.addEvent(event)
                
                let startDateString = event.startDate != nil ? "\(DateFormatter.germanLongDate.string(from: event.startDate!)) \(DateFormatter.germanShortTime.string(from: event.startDate!))" : ""
                let endDateString = event.endDate != nil ? "\(DateFormatter.germanLongDate.string(from: event.endDate!)) \(DateFormatter.germanShortTime.string(from: event.endDate!))" : ""
                                
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Event \"\(event.title)\" created successfully \(event.startDate != nil && event.endDate != nil ? "from \(startDateString) to \(endDateString)" : "and added it to an Unassigned folder").\"}", name: "createEvent", tool_call_id: toolCall.id)
                
                return functionResponseMessage
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Failed to decode arguments for createEvent: \(error.localizedDescription).\"}", name: "getEvents", tool_call_id: toolCall.id)
                
                return functionResponseMessage
            }
            
        case "modifyEvent":
            guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Invalid arguments format was used for modifyEvent.\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                
                return functionResponseMessage
            }
            do {
                let modifyArgs = try JSONDecoder().decode(ModifyEventArgs.self, from: argsData)
                let sanitizedOriginalDate = Date.sanitizeISODate(modifyArgs.originalDate ?? "")
                let lookupDate = DateFormatter.localDateFormatter.date(from: sanitizedOriginalDate)
                var event: Event
                
                if let eventId = modifyArgs.eventId {
                    guard let uuid = await eventContextManager.uuid(forTemporaryId: eventId) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Invalid UUID for event context manager: \(eventId).\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                        
                        return functionResponseMessage
                    }
                    guard let potentialEvent = eventService.getEvent(byId: uuid) else {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"No matching event found due to the incorrect mapping of id.\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                        
                        return functionResponseMessage
                    }
                    event = potentialEvent
                } else {
                    let events = eventService.getEvents(byDates: lookupDate != nil ? [lookupDate!] : nil, byTitle: modifyArgs.originalTitle)
                    
                    if events.isEmpty {
                        let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"No event matching title=\(String(describing: modifyArgs.originalTitle)), date=\(String(describing: lookupDate)) found.\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                        
                        return functionResponseMessage
                    } else if events.count > 1 {
                        await eventContextManager.setEventsCacheAndIdMap(events)
                        let summaries = await eventContextManager.getCurrentEventCacheKnowledge() ?? ""
                        let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Multiple events found.\", \"summaries\": \(summaries)}", name: "modifyEvent", tool_call_id: toolCall.id)

                        
                        return functionResponseMessage
                    } else {
                        event = events[0]
                    }
                }
                
                if event.recurrenceType != .none && lookupDate == nil {
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Could not specify the originalDate for the occurence of the recurring event \"\(event.title)\" .\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                    
                    return functionResponseMessage
                }
                
                switch modifyArgs.action {
                case "update":
                    var updatedEvent = event
                    let now = Date()
                    updatedEvent.isCompleted = false
                    if let newTitle = modifyArgs.newTitle, !newTitle.isEmpty {
                        updatedEvent.title = newTitle
                    }
                    
                    var changedRecurrence = false
                    if let newRecurrenceTypeStr = modifyArgs.newRecurrenceType,
                        let recurrenceType = RecurrenceType.fromString(newRecurrenceTypeStr) {
                        updatedEvent.recurrenceType = recurrenceType
                        changedRecurrence = true
                    }
                    if let newRecurrenceInterval = modifyArgs.newRecurrenceInterval {
                        updatedEvent.recurrenceInterval = newRecurrenceInterval
                        changedRecurrence = true
                    }
                    
                    // 1) Try parsing each incoming string (nil or empty → nil Date)
                    let parsedStartDate: Date? = {
                        guard let s = modifyArgs.newStartDate, !s.isEmpty else { return nil }
                        let sanitized = Date.sanitizeISODateTime(s)
                        return DateFormatter.localDateTimeFormatter.date(from: sanitized)
                    }()

                    let parsedEndDate: Date? = {
                        guard let s = modifyArgs.newEndDate, !s.isEmpty else { return nil }
                        let sanitized = Date.sanitizeISODateTime(s)
                        return DateFormatter.localDateTimeFormatter.date(from: sanitized)
                    }()

                    // 2) If either was explicitly emptied, clear everything
                    if modifyArgs.newStartDate == "" || modifyArgs.newEndDate == "" {
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
                    if let newNotificationInterval = modifyArgs.newNotificationInterval {
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
                    
                    let operationString = event.isCompleted ? "rescheduled" : "updated"
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Event \"\(event.title)\" \(operationString) successfully.\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                    return functionResponseMessage
                case "delete":
                    if modifyArgs.applyForAllAfter == true && event.recurrenceType != .none {
                        eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                    } else if event.recurrenceType != .none {
                        eventService.deleteOccurrence(of: event, on: lookupDate ?? Date())
                    } else {
                        eventService.deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
                    }
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Event \"\(event.title)\" deleted successfully.\"}", name: "modifyEvent", tool_call_id: toolCall.id)
                    
                    return functionResponseMessage
                case "toggleCompletion":
                    eventService.toggleEventCompletion(event, on: lookupDate ?? Date())
                    
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Event \"\(event.title)\" completion toggled successfully.\"}", name: "modifyEvent", tool_call_id: toolCall.id)

                    return functionResponseMessage
                    
                default:
                    let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Unhandled action: \(modifyArgs.action).\"}", name: toolCall.function.name, tool_call_id: toolCall.id)
                    return functionResponseMessage
                }
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Failed to decode arguments for modifyEvent: \(error.localizedDescription).\"}", name: toolCall.function.name, tool_call_id: toolCall.id)
                
                return functionResponseMessage
            }
            
        case "getEvents":
            guard let argsData = toolCall.function.arguments.data(using: .utf8) else {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Invalid arguments format was used for getEvents.\"}", name: "getEvents", tool_call_id: toolCall.id)
                return functionResponseMessage
            }
            do {
                let getEventsArgs = try JSONDecoder().decode(GetEventsArgs.self, from: argsData)
                let dates = getEventsArgs.specificDates?.compactMap { DateFormatter.localDateFormatter.date(from: Date.sanitizeISODate($0)) } ?? Date.dateSpan(from: DateFormatter.localDateFormatter.date(from: Date.sanitizeISODate(getEventsArgs.dateFrom ?? "")), to: DateFormatter.localDateFormatter.date(from: Date.sanitizeISODate(getEventsArgs.dateTo ?? "")))
                
                let events = eventService.getEvents(byDates: dates, byTitle: getEventsArgs.titleQuery, undatedOnly: getEventsArgs.undatedOnly ?? false)
                print("Tool found events: \(events)")
                await eventContextManager.setEventsCacheAndIdMap(events)
                let summaries = await eventContextManager.getCurrentEventCacheKnowledge() ?? ""
                
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"result\": \"Events retrieved successfully.\", \"summaries\": \(summaries)}", name: "getEvents", tool_call_id: toolCall.id)
                
                return functionResponseMessage
            } catch {
                let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Failed to decode arguments for getEvents: \(error.localizedDescription).\"}", name: "getEvents", tool_call_id: toolCall.id)
                return functionResponseMessage
            }
                
        default:
            let functionResponseMessage = ChatMessage(role: .tool, content: "{\"error\": \"Unhandled function: \(toolCall.function.name).\"}", name: toolCall.function.name, tool_call_id: toolCall.id)
            return functionResponseMessage
        }
    }

    /// Centralized “end of convo” entrypoint.
    func endConversation(_ messages: [Message]) async {
        // Grab whatever chat you’ve collected so far:
        let memory = memoryService.fetchLongTermMemory()
        print(memory.knowledge)
        let messages: [ChatMessage] = messages.filter { !$0.isFactChecked }.map { message in ChatMessage(role: message.isFromUser ? .user : .assistant, content: message.content) }
        // Run your batch‑analysis (instead of per‑message):
        let newFacts = await factExtractionService.extractNewFacts(messages, knownFacts: memory.knowledge.enumerated().map { (index, fact) in "\(index + 1)) Key: \(fact.key); Value: \(fact.value)" })
        print("New facts: \(newFacts)")
        await memoryService.changeLongTermMemory(newEmotion: nil, newFacts: newFacts, newPersonalityProfile: nil)
        // Optionally: clear the short‑term memory buffer?
        // memoryService.clearShortTermMemory()
    }
    
    func refreshLastConversation(_ messages: [Message]) {
        if (memoryService.fetchShortTermMemory().isEmpty || memoryService.fetchShortTermMemory().isEmpty) {
            memoryService.changeShortTermMemory(messages.map { message in ChatMessage(role: message.isFromUser ? .user : .assistant, content: message.content) })
        }
        print("Refreshed short term memory: \(memoryService.fetchShortTermMemory())")
    }
    
    func reset() {
        memoryService.clearMemory()
    }
}
