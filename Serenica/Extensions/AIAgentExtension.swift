import Foundation

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
        let factKeys = knowledge.prefix(3).map { $0.key }
        let knowledgeSummary = "Knowledge: \(knowledge.count) fact(s)" + (factKeys.isEmpty ? "" : " [\(factKeys.joined(separator: ","))]")
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



// Decoded args for fetching events
struct GetEventsArgs: Codable {
    let date: String?
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
}

// Decoded args for modifying an event
struct ModifyEventArgs: Codable {
    let eventId: Int
    let date: String?
    let action: String
    let applyForAllAfter: Bool?
    let title: String?
    let startDate: String?
    let endDate: String?
    let notificationInterval: Int?
    let recurrenceType: String?
    let recurrenceInterval: Int?
}
