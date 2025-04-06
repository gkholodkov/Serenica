import Foundation

struct BigFiveProfile: Equatable {
    var openness: Double
    var conscientiousness: Double
    var extraversion: Double
    var agreeableness: Double
    var neuroticism: Double
}

struct HEXACOProfile: Equatable {
    var honestyHumility: Double
    var emotionality: Double
    var extraversion: Double
    var agreeableness: Double
    var conscientiousness: Double
    var opennessToExperience: Double
}

enum MBTIType: String {
    case INFJ, INFP, ENFJ, ENFP, INTJ, INTP, ENTJ, ENTP,
         ISFJ, ISTJ, ESFJ, ESTJ, ISFP, ISTP, ESFP, ESTP
}

struct PersonalityProfile: Equatable {
    var bigFive: BigFiveProfile
    var hexaco: HEXACOProfile
    var mbti: MBTIType
    
    static func == (lhs: PersonalityProfile, rhs: PersonalityProfile) -> Bool {
        return lhs.bigFive == rhs.bigFive && lhs.hexaco == rhs.hexaco && lhs.mbti == rhs.mbti
    }
}
