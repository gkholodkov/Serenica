import Foundation

enum EmotionLabel: String {
    case anger, joy, sadness, happiness, fear, surprise, disgust, calm, confusion, guilt, shame, pride, jealousy, envy, nostalgia, ambivalence, curiosity, contempt, awe, bittersweet, schadenfreude, honor, dignity, excitement, regret
    
    static func from(_ string: String) -> EmotionLabel? {
        return EmotionLabel(rawValue: string)
    }
    
    static func from(pleasure: Double, arousal: Double, dominance: Double) -> EmotionLabel {
        if pleasure > 0.5 {
            if arousal > 0.7 {
                if dominance < 0 {
                    return .awe
                } else {
                    return .excitement
                }
            } else if arousal > 0.5 {
                if dominance > 0.5 {
                    return .pride
                } else if dominance > 0 {
                    return .schadenfreude
                } else {
                    return .happiness
                }
            } else if arousal > 0.3 {
                if dominance > -0.2 && dominance < 0.2 {
                    return .curiosity
                } else {
                    return .happiness
                }
            } else {
                if dominance > 0.5 {
                    return .honor
                } else {
                    return .joy
                }
            }
        }
        else if pleasure < -0.5 {
            if arousal > 0.6 {
                if dominance > 0.5 {
                    return .anger
                } else if dominance > 0 {
                    return .contempt
                } else if dominance > -0.5 {
                    return .fear
                } else {
                    return .envy
                }
            } else if arousal > 0.5 {
                if dominance < 0 {
                    return .jealousy
                } else {
                    return .contempt
                }
            } else {
                if dominance < -0.5 {
                    return .shame
                } else if dominance < 0 {
                    if arousal < 0.5 {
                        return .regret
                    } else {
                        return .guilt
                    }
                } else {
                    return .sadness
                }
            }
        }
        else {
            if arousal > 0.7 {
                return .surprise
            } else if arousal < 0.5 {
                if pleasure > 0.2 {
                    return .nostalgia
                } else if pleasure > -0.2 {
                    return .ambivalence
                } else if pleasure > -0.5 {
                    return .bittersweet
                } else {
                    return .calm
                }
            } else {
                if dominance < 0 {
                    return .confusion
                } else {
                    return .disgust
                }
            }
        }
    }
}

struct Emotion: Equatable {
    var pleasure: Double;   // e.g., range from -1.0 (unpleasant) to 1.0 (pleasant)
    var arousal: Double    // e.g., range from 0.0 (calm) to 1.0 (excited)
    var dominance: Double  // e.g., range from 0.0 (submissive) to 1.0 (dominant)
    var label: EmotionLabel?  // e.g., determined by additional heuristics or ML model
    var timestamp: Date
}
