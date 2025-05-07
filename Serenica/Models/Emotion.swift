import Foundation

enum EmotionLabel: String {
    // — High Pleasure —
    case elation         // (H, H, H)
    case exhilaration    // (H, H, M)
    case wonder          // (H, H, L)
    case pride           // (H, M, H)
    case joy             // (H, M, M)
    case amusement       // (H, M, L)
    case confidence      // (H, L, H)
    case contentment     // (H, L, M)
    case serenity        // (H, L, L)

    // — Mid Pleasure —
    case vigilance       // (M, H, H)
    case surprise        // (M, H, M)
    case startle         // (M, H, L)
    case interest        // (M, M, H)
    case neutrality      // (M, M, M)
    case reflection      // (M, M, L)
    case composure       // (M, L, H)
    case relaxation      // (M, L, M)
    case boredom         // (M, L, L)

    // — Low Pleasure —
    case rage            // (L, H, H)
    case anger           // (L, H, M)
    case fear            // (L, H, L)
    case contempt        // (L, M, H)
    case disgust         // (L, M, M)
    case guilt           // (L, M, L)
    case regret          // (L, L, H)
    case sadness         // (L, L, M)
    case despair         // (L, L, L)
    
    static func from(_ string: String) -> EmotionLabel? {
        return EmotionLabel(rawValue: string)
    }
    
    static func level(_ x: Double, low: Double, high: Double) -> Level {
        switch x {
            case ..<low:     return .Low
            case high...:    return .High
            default:         return .Mid
        }
    }

    static func from(pleasure p: Double, arousal a: Double, dominance d: Double) -> EmotionLabel {
        let pL = level(p, low: EmotionThresholds.pNegative, high: EmotionThresholds.pPositive)
        let aL = level(a, low: EmotionThresholds.aLow, high: EmotionThresholds.aHigh)
        let dL = level(d, low: EmotionThresholds.dLow, high: EmotionThresholds.dHigh)
        return EmotionLevelCollection.emotionMap[PADKey(p: pL, a: aL, d: dL)]!
    }
}

struct EmotionThresholds {
    // pleasure: low < –0.5, mid between –0.5…0.5, high > 0.5
    static let pNegative  = -0.5
    static let pPositive  =  0.5

    // arousal: low <  0.3, mid between  0.3…0.7, high > 0.7
    static let aLow    =  0.3
    static let aHigh   =  0.7

    // dominance: low <  0.0, mid between  0.0…0.5, high > 0.5
    static let dLow  =  0.0
    static let dHigh =  0.5
}

enum Level: String { case Low, Mid, High }

struct PADKey: Hashable {
    let p: Level
    let a: Level
    let d: Level
}

struct Emotion: Equatable {
    var pleasure: Double;   // e.g., range from -1.0 (unpleasant) to 1.0 (pleasant)
    var arousal: Double    // e.g., range from 0.0 (calm) to 1.0 (excited)
    var dominance: Double  // e.g., range from 0.0 (submissive) to 1.0 (dominant)
    var label: EmotionLabel?  // e.g., determined by additional heuristics or ML model
    var timestamp: Date
    var consecutiveOccurrences: Int = 1
}
