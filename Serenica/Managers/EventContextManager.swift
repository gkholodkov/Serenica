import Foundation


actor EventContextManager {
    private var eventMap: [Int: UUID] = [:]
    private var eventsCache: [String] = []
    
    func setEventsCacheAndIdMap(_ events: [Event]) {
        eventMap.removeAll()
        eventsCache.removeAll()
        var summaries: [String] = []
        for (index, event) in events.enumerated() {
            eventMap[index + 1] = event.id
            summaries.append("{\"eventId\": \(index + 1), \"title\": \"\(event.title)\", \"startDate\": \"\(String(describing: event.startDate))\", \"endDate\": \"\(String(describing: event.endDate))\", \"recurrenceType\": \"\(event.recurrenceType)\", \"recurrenceInterval\": \(event.recurrenceInterval), \"isCompleted\": \(event.isCompleted)}")
        }
        eventsCache = summaries
    }

    func uuid(forTemporaryId id: Int) -> UUID? {
        eventMap[id]
    }
    
    func getCurrentEventCacheKnowledge() -> String? {
        let summary = eventsCache.joined(separator: ", ")
        guard !summary.isEmpty else { return nil }
        
        return "[\(summary)]"
    }
}
