import Foundation


actor EventContextManager {
    private var eventMap: [Int: UUID] = [:]
    private var eventsCache: [String] = []
    
    func setEventsCacheAndIdMap(_ events: [Event]) {
        eventMap.removeAll()
        var summaries: [String] = []
        for (index, event) in events.enumerated() {
            eventMap[index + 1] = event.id
            summaries.append("(\(index + 1)) \(event.summary)")
        }
        eventsCache = summaries
    }

    func uuid(forTemporaryId id: Int) -> UUID? {
        eventMap[id]
    }
    
    func getCurrentEventCacheKnowledge() -> String? {
        let summary = eventsCache.joined(separator: "\n")
        guard !summary.isEmpty else { return nil }
        
        return "{\"summaries\": \"\(summary)\"}"
    }
}
