import Foundation

struct PersonalityCreationService {
    private let dynamicWeight: Double = 0.5

    func derivePersonality(from initialPersonality: PersonalityProfile?, usingEmotions emotions: [Emotion]) -> PersonalityProfile {
        // Helper to clamp any score into [-1…+1]
        func clamp(_ x: Double) -> Double {
            return min(max(x, -1.0), 1.0)
        }
        
        func round2(_ x: Double) -> Double {
            return (x * 100).rounded() / 100
        }
        
        let f = emotions.extractDynamics()
            
        // —— Big Five —— //
        // Openness: driven by mean Pleasure & Arousal, slight bonus for rising A
        let opennessBF = clamp(0.45 * f.meanP + 0.45 * f.meanA + 0.10 * f.slopeA)
            
        // Conscientiousness: higher when Dominance is high and arousal variability is low
        let conscientiousnessBF = clamp(0.6 * f.meanD + 0.4 * (1.0 - f.sigmaA))
        
        // Extraversion: average of mean P/A/D and rising P/A
        let extraversionBF = clamp(
            0.25 * f.meanP +
            0.25 * f.meanA +
            0.20 * f.meanD +
            0.15 * f.slopeP +
            0.15 * f.slopeA
        )
            
        // Agreeableness: goes down when Dominance or volatility in D is high
        let agreeablenessBF = clamp(-0.6 * f.meanD - 0.4 * f.sigmaD)
        
        // Neuroticism: rises with P‑downward trend and high variability in P/A
        let neuroticismBF = clamp(
            0.4 * f.sigmaP +
            0.3 * f.sigmaA +
            0.2 * max(0, -f.slopeP) +
            0.1 * f.sigmaD
        )
            
        let bigFive = BigFiveProfile(
            openness:          opennessBF,
            conscientiousness: conscientiousnessBF,
            extraversion:      extraversionBF,
            agreeableness:     agreeablenessBF,
            neuroticism:       neuroticismBF
        )
            
        // —— HEXACO —— //
        // Honesty‑Humility: low Dominance & low volatility in D
        let honestyHumility = clamp(-0.7 * f.meanD + 0.3 * (1.0 - f.sigmaD))
            
        // Emotionality: similar to neuroticism but includes dominance drop
        let emotionality = clamp(
            0.3 * f.sigmaP +
            0.3 * f.sigmaA +
            0.2 * max(0, -f.meanD) +
            0.2 * f.sigmaD
        )
            
        // Extraversion & Agreeableness reuse BigFive versions
        let extraversionHX = extraversionBF
        let agreeablenessHX = agreeablenessBF
            
        // Conscientiousness & OpennessToExperience map directly
        let conscientiousnessHX = conscientiousnessBF
        let opennessHX       = opennessBF
            
        let hexaco = HEXACOProfile(
            honestyHumility:       honestyHumility,
            emotionality:          emotionality,
            extraversion:          extraversionHX,
            agreeableness:         agreeablenessHX,
            conscientiousness:     conscientiousnessHX,
            opennessToExperience:  opennessHX
        )
        
        var blendedBigFive: BigFiveProfile
        var blendedHEXACO: HEXACOProfile
        var blendedMBTI: MBTIType
        
        if let initP = initialPersonality {
            // Big Five
            blendedBigFive = BigFiveProfile(
                openness:          round2(dynamicWeight * bigFive.openness          + (1 - dynamicWeight) * initP.bigFive.openness),
                conscientiousness: round2(dynamicWeight * bigFive.conscientiousness + (1 - dynamicWeight) * initP.bigFive.conscientiousness),
                extraversion:      round2(dynamicWeight * bigFive.extraversion      + (1 - dynamicWeight) * initP.bigFive.extraversion),
                agreeableness:     round2(dynamicWeight * bigFive.agreeableness     + (1 - dynamicWeight) * initP.bigFive.agreeableness),
                neuroticism:       round2(dynamicWeight * bigFive.neuroticism       + (1 - dynamicWeight) * initP.bigFive.neuroticism)
            )
            // HEXACO
            blendedHEXACO = HEXACOProfile(
                honestyHumility:      round2(dynamicWeight * hexaco.honestyHumility      + (1 - dynamicWeight) * initP.hexaco.honestyHumility),
                emotionality:         round2(dynamicWeight * hexaco.emotionality        + (1 - dynamicWeight) * initP.hexaco.emotionality),
                extraversion:         round2(dynamicWeight * hexaco.extraversion         + (1 - dynamicWeight) * initP.hexaco.extraversion),
                agreeableness:        round2(dynamicWeight * hexaco.agreeableness        + (1 - dynamicWeight) * initP.hexaco.agreeableness),
                conscientiousness:    round2(dynamicWeight * hexaco.conscientiousness    + (1 - dynamicWeight) * initP.hexaco.conscientiousness),
                opennessToExperience: round2(dynamicWeight * hexaco.opennessToExperience              + (1 - dynamicWeight) * initP.hexaco.opennessToExperience)
            )
        } else {
            // No initial: use dynamic + rounding
            blendedBigFive = bigFive
            blendedHEXACO = hexaco
        }
        
        // —— MBTI —— //
        // E vs I
        let letter1 = blendedBigFive.extraversion >= 0 ? "E" : "I"
        // N vs S (high openness → N)
        let letter2 = blendedBigFive.openness      >= 0 ? "N" : "S"
        // F vs T (high agreeableness → F)
        let letter3 = blendedBigFive.agreeableness >= 0 ? "F" : "T"
        // J vs P (high conscientiousness → J)
        let letter4 = blendedBigFive.conscientiousness >= 0 ? "J" : "P"
            
        blendedMBTI = MBTIType(rawValue: letter1 + letter2 + letter3 + letter4)!

            
        return PersonalityProfile(
            bigFive: blendedBigFive,
            hexaco:  blendedHEXACO,
            mbti:    blendedMBTI
        )
    }
}
