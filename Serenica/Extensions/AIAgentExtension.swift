import Foundation
import CoreData

extension Memory {
    func toString() -> String {
        var parts: [String] = []
        
        // Personality summary.
        if let personality = self.personality {
            let personalitySummary = "Personality: MBTI=\(personality.mbti.rawValue), BigFive=(O:\(personality.bigFive.openness), C:\(personality.bigFive.conscientiousness), E:\(personality.bigFive.extraversion), A:\(personality.bigFive.agreeableness), N:\(personality.bigFive.neuroticism)), HEXACO=(H:\(personality.hexaco.honestyHumility), E:\(personality.hexaco.emotionality), E:\(personality.hexaco.extraversion), A:\(personality.hexaco.agreeableness), C:\(personality.hexaco.conscientiousness), O:\(personality.hexaco.opennessToExperience))"
            parts.append(personalitySummary)
        } else {
            parts.append("No Personality")
        }
        
        // Knowledge summary.
        let facts = knowledge.filter({ fact in
            fact.ttl == nil || fact.importance >= 9
        }).shuffled().prefix(5).map { "\($0.key): \($0.value)" }
        let knowledgeSummary = "Knowledge: \(knowledge.count) fact(s)." + (facts.isEmpty ? "" : "\(facts.count) random fact(s): [\(facts.joined(separator: ","))]")
        parts.append(knowledgeSummary)
        
        // Emotional state summary.
        parts.append("Emotions: \(emotionalState.count) recorded with average PAD score (P:\(emotionalState.reduce(0) { $0 + $1.pleasure } / Double(emotionalState.count)), A:\(emotionalState.reduce(0) { $0 + $1.arousal } / Double(emotionalState.count)), D:\(emotionalState.reduce(0) { $0 + $1.dominance } / Double(emotionalState.count)))")
        
        // Today's emotion summary.
        if let todays = todaysEmotion {
            let todaysSummary = "Today's Emotion: \(todays.label?.rawValue ?? "Unlabeled") (P:\(todays.pleasure), A:\(todays.arousal), D:\(todays.dominance))"
            parts.append(todaysSummary)
        } else {
            parts.append("No Today's Emotion")
        }
        
        // Join all parts into one concise string.
        return "Memory Summary: " + parts.joined(separator: " | ")
    }
}

extension [Emotion] {
    func averageEmotion() -> Emotion {
        return Emotion(
            pleasure: self.reduce(into: 0) { result, emotion in result += emotion.pleasure } / Double(self.count),
            arousal: self.reduce(into: 0) { result, emotion in result += emotion.arousal } / Double(self.count),
            dominance: self.reduce(into: 0) { result, emotion in result += emotion.dominance } / Double(self.count),
            timestamp: self.last?.timestamp ?? Date()
        )
    }
    
    func extractDynamics() -> (meanP: Double, meanA: Double, meanD: Double, slopeP: Double, slopeA: Double, slopeD: Double, sigmaP: Double, sigmaA: Double, sigmaD: Double) {
        guard self.count >= 2 else {
            // fallback to zeros
            return (meanP:0, meanA:0, meanD:0,
                        slopeP:0, slopeA:0, slopeD:0,
                        sigmaP:0, sigmaA:0, sigmaD:0)
        }
        
        let ps = self.map(\.pleasure)
        let as_ = self.map(\.arousal)
        let ds = self.map(\.dominance)
            
        func mean(_ xs:[Double]) -> Double {
            xs.reduce(0,+)/Double(xs.count)
        }
        func stddev(_ xs:[Double], μ:Double) -> Double {
            let varSum = xs.map { pow($0-μ,2) }.reduce(0,+)
            return sqrt(varSum / Double(xs.count))
        }
            
        let μP = mean(ps), μA = mean(as_), μD = mean(ds)
        let σP = stddev(ps, μ:μP),
            σA = stddev(as_, μ:μA),
            σD = stddev(ds, μ:μD)
        
        func slope(values: [Double], times: [TimeInterval]) -> Double {
            let μx = mean(times.map { Double($0) })
            let μy = mean(values)
            let numerator = zip(times, values)
                .map { (t,y) in (Double(t)-μx)*(y-μy) }
                .reduce(0,+)
            let denominator = times.map { pow(Double($0)-μx,2) }.reduce(0,+)
            return denominator != 0 ? numerator/denominator : 0
        }
        
        let timestamps = self.map { $0.timestamp.timeIntervalSince1970 }
        let slopeP = slope(values: ps,  times: timestamps)
        let slopeA = slope(values: as_, times: timestamps)
        let slopeD = slope(values: ds,  times: timestamps)
        
        return (meanP: μP, meanA: μA, meanD: μD,
                slopeP: slopeP, slopeA: slopeA, slopeD: slopeD,
                sigmaP: σP, sigmaA: σA, sigmaD: σD)
    }
    
    func weightedModeLabel(
        timeDecayLambda λ: Double = 0.0,
        intensityAlpha α: Double = 1.0
    ) -> EmotionLabel?
    {
        let now = Date()
        var scoreByLabel = [EmotionLabel: Double]()

        for emo in self {
            // 1) Discretize into PADKey
            let pL = EmotionLabel.level(emo.pleasure,
                                        low: EmotionThresholds.pNegative,
                                        high: EmotionThresholds.pPositive)
            let aL = EmotionLabel.level(emo.arousal,
                                        low: EmotionThresholds.aLow,
                                        high: EmotionThresholds.aHigh)
            let dL = EmotionLabel.level(emo.dominance,
                                        low: EmotionThresholds.dLow,
                                        high: EmotionThresholds.dHigh)
            let key = PADKey(p: pL, a: aL, d: dL)
            guard let lbl = EmotionLevelCollection.emotionMap[key] else { continue }

            // 2) Compute bucket-center for each dimension
            let pCenter: Double = {
                switch pL {
                case .Low:  return (-1.0 + EmotionThresholds.pNegative) / 2
                case .Mid:  return (EmotionThresholds.pNegative + EmotionThresholds.pPositive) / 2
                case .High: return (EmotionThresholds.pPositive + 1.0) / 2
                }
            }()
            let aCenter: Double = {
                switch aL {
                case .Low:  return (0.0 + EmotionThresholds.aLow) / 2
                case .Mid:  return (EmotionThresholds.aLow + EmotionThresholds.aHigh) / 2
                case .High: return (EmotionThresholds.aHigh + 1.0) / 2
                }
            }()
            let dCenter: Double = {
                switch dL {
                case .Low:  return (0.0 + EmotionThresholds.dLow) / 2
                case .Mid:  return (EmotionThresholds.dLow + EmotionThresholds.dHigh) / 2
                case .High: return (EmotionThresholds.dHigh + 1.0) / 2
                }
            }()

            // 3) Intensity weight = 1 + α * EuclideanDistance
            let dist = sqrt(
                pow(emo.pleasure - pCenter, 2) +
                pow(emo.arousal - aCenter, 2) +
                pow(emo.dominance - dCenter, 2)
            )
            let intensityWeight = 1.0 + α * dist

            // 4) Time-decay weight = exp(−λ · Δt)
            let timeWeight: Double = λ > 0
                ? exp(-λ * now.timeIntervalSince(emo.timestamp))
                : 1.0
            
            let occurrenceWeight = Double(emo.consecutiveOccurrences)

            // 5) Vote
            let vote = intensityWeight * timeWeight * occurrenceWeight
            scoreByLabel[lbl, default: 0.0] += vote
        }

        // 6) Return the label with max total vote
        return scoreByLabel.max(by: { $0.value < $1.value })?.key
    }
}

extension PersonalityProfile {
    
    mutating func updateBasedOnEmotion(_ emotion: Emotion, adjustmentFactor: Double = 0.1) {
        
        // Update Big Five
        bigFive.extraversion += adjustmentFactor * (emotion.pleasure + emotion.arousal + (emotion.dominance - 0.5))
        bigFive.openness += adjustmentFactor * (emotion.pleasure + emotion.arousal) / 2
        bigFive.neuroticism += adjustmentFactor * (-emotion.pleasure + emotion.arousal)
        bigFive.agreeableness += adjustmentFactor * (0.5 - emotion.dominance)
        
        // Clamping Big Five traits between 0.0 and 1.0
        bigFive.extraversion = clamp(bigFive.extraversion)
        bigFive.openness = clamp(bigFive.openness)
        bigFive.neuroticism = clamp(bigFive.neuroticism)
        bigFive.agreeableness = clamp(bigFive.agreeableness)
        
        // Update HEXACO
        hexaco.extraversion += adjustmentFactor * (emotion.pleasure + emotion.arousal + (emotion.dominance - 0.5))
        hexaco.opennessToExperience += adjustmentFactor * (emotion.pleasure + emotion.arousal) / 2
        hexaco.emotionality += adjustmentFactor * (-emotion.pleasure + emotion.arousal + (0.5 - emotion.dominance))
        hexaco.agreeableness += adjustmentFactor * (0.5 - emotion.dominance)
        
        // Clamping HEXACO traits between 0.0 and 1.0
        hexaco.extraversion = clamp(hexaco.extraversion)
        hexaco.opennessToExperience = clamp(hexaco.opennessToExperience)
        hexaco.emotionality = clamp(hexaco.emotionality)
        hexaco.agreeableness = clamp(hexaco.agreeableness)
        
        // MBTI Adjustment based on thresholds
        adjustMBTI()
    }
    
    private func clamp(_ value: Double, min: Double = 0.0, max: Double = 1.0) -> Double {
        return Swift.min(max, Swift.max(min, value))
    }
    
    private mutating func adjustMBTI() {
        // Extraversion/Introversion adjustment (already implemented)
        if bigFive.extraversion > 0.6 {
            mbti = (mbti.rawValue.contains("I")) ? mbti.flipIntroversion() : mbti
        } else if bigFive.extraversion < 0.4 {
            mbti = (mbti.rawValue.contains("E")) ? mbti.flipExtraversion() : mbti
        }
        
        // Sensing/Intuition adjustment based on openness
        if bigFive.openness > 0.6 {
            // Higher openness nudges from S to N
            mbti = (mbti.rawValue.contains("S")) ? mbti.flipSensing() : mbti
        } else if bigFive.openness < 0.4 {
            // Lower openness nudges from N to S
            mbti = (mbti.rawValue.contains("N")) ? mbti.flipIntuition() : mbti
        }
        
        // Thinking/Feeling adjustment based on agreeableness
        if bigFive.agreeableness > 0.6 {
            // Higher agreeableness favors Feeling over Thinking
            mbti = (mbti.rawValue.contains("T")) ? mbti.flipThinking() : mbti
        } else if bigFive.agreeableness < 0.4 {
            // Lower agreeableness favors Thinking over Feeling
            mbti = (mbti.rawValue.contains("F")) ? mbti.flipFeeling() : mbti
        }
        
        // Judging/Perceiving adjustment based on neuroticism
        if bigFive.neuroticism < 0.4 {
            // Lower neuroticism may correlate with a more structured (Judging) approach
            mbti = (mbti.rawValue.contains("P")) ? mbti.flipPerceiving() : mbti
        } else if bigFive.neuroticism > 0.6 {
            // Higher neuroticism might correlate with a more flexible (Perceiving) approach
            mbti = (mbti.rawValue.contains("J")) ? mbti.flipJudging() : mbti
        }
    }

}

extension MBTIType {
    // Existing implementations for Introversion/Extraversion
    func flipIntroversion() -> MBTIType {
        let mapping: [MBTIType: MBTIType] = [
            .INFJ: .ENFJ, .INFP: .ENFP, .INTJ: .ENTJ, .INTP: .ENTP,
            .ISFJ: .ESFJ, .ISTJ: .ESTJ, .ISFP: .ESFP, .ISTP: .ESTP
        ]
        return mapping[self] ?? self
    }
    
    func flipExtraversion() -> MBTIType {
        let mapping: [MBTIType: MBTIType] = [
            .ENFJ: .INFJ, .ENFP: .INFP, .ENTJ: .INTJ, .ENTP: .INTP,
            .ESFJ: .ISFJ, .ESTJ: .ISTJ, .ESFP: .ISFP, .ESTP: .ISTP
        ]
        return mapping[self] ?? self
    }
    
    // Sensing (S) vs. Intuition (N) flips
    func flipSensing() -> MBTIType {
        // For types with S in the second position, switch to N.
        let mapping: [MBTIType: MBTIType] = [
            .ISTJ: .INTJ, .ISTP: .INTP, .ISFJ: .INFJ, .ISFP: .INFP,
            .ESTJ: .ENTJ, .ESTP: .ENTP, .ESFJ: .ENFJ, .ESFP: .ENFP
        ]
        return mapping[self] ?? self
    }
    
    func flipIntuition() -> MBTIType {
        // For types with N in the second position, switch to S.
        let mapping: [MBTIType: MBTIType] = [
            .INTJ: .ISTJ, .INTP: .ISTP, .INFJ: .ISFJ, .INFP: .ISFP,
            .ENTJ: .ESTJ, .ENTP: .ESTP, .ENFJ: .ESFJ, .ENFP: .ESFP
        ]
        return mapping[self] ?? self
    }
    
    // Thinking (T) vs. Feeling (F) flips
    func flipThinking() -> MBTIType {
        // For types with T in the third position, switch to F.
        let mapping: [MBTIType: MBTIType] = [
            .ISTJ: .ISFJ, .ISTP: .ISFP, .ESTJ: .ESFJ, .ESTP: .ESFP,
            .INTJ: .INFJ, .INTP: .INFP, .ENTJ: .ENFJ, .ENTP: .ENFP
        ]
        return mapping[self] ?? self
    }
    
    func flipFeeling() -> MBTIType {
        // For types with F in the third position, switch to T.
        let mapping: [MBTIType: MBTIType] = [
            .ISFJ: .ISTJ, .ISFP: .ISTP, .ESFJ: .ESTJ, .ESFP: .ESTP,
            .INFJ: .INTJ, .INFP: .INTP, .ENFJ: .ENTJ, .ENFP: .ENTP
        ]
        return mapping[self] ?? self
    }
    
    // Judging (J) vs. Perceiving (P) flips
    func flipJudging() -> MBTIType {
        // For types with J as the fourth letter, switch to P.
        let mapping: [MBTIType: MBTIType] = [
            .ISTJ: .ISTP, .ISFJ: .ISFP, .INTJ: .INTP, .INFJ: .INFP,
            .ESTJ: .ESTP, .ESFJ: .ESFP, .ENTJ: .ENTP, .ENFJ: .ENFP
        ]
        return mapping[self] ?? self
    }
    
    func flipPerceiving() -> MBTIType {
        // For types with P as the fourth letter, switch to J.
        let mapping: [MBTIType: MBTIType] = [
            .ISTP: .ISTJ, .ISFP: .ISFJ, .INTP: .INTJ, .INFP: .INFJ,
            .ESTP: .ESTJ, .ESFP: .ESFJ, .ENTP: .ENTJ, .ENFP: .ENFJ
        ]
        return mapping[self] ?? self
    }
}

enum EndReason {
  case idleTimeout, appBackground, viewDismissed
}

// Decoded args for fetching events
struct GetEventsArgs: Codable {
    let dateFrom: String?
    let dateTo: String?
    let specificDates: [String]?
    let titleQuery: String?
}

// Decoded args for creating an event
struct CreateEventArgs: Codable {
    let title: String
    let startDate: String?
    let endDate: String?
    let notificationInterval: Int?
    let recurrenceType: String?
    let recurrenceInterval: Int?
    let recurrenceEndDate: String?
    let notes: String?
}

// Decoded args for modifying an event
struct ModifyEventArgs: Codable {
    let eventId: Int?
    let originalTitle: String?
    let originalDate: String?
    let action: String
    let applyForAllAfter: Bool?
    let newTitle: String?
    let newStartDate: String?
    let newEndDate: String?
    let newNotificationInterval: Int?
    let newRecurrenceType: String?
    let newRecurrenceInterval: Int?
}

struct EmotionArgs: Codable {
    let pleasure: Double
    let arousal: Double
    let dominance: Double
    let label: String
}

struct FactArgs: Codable {
    let factKey: String
    let factValue: String
    let timeToLive: Int?
    let importance: Int
}
