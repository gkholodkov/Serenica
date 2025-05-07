import Foundation

struct LexiconSentimentRecognitionService {
    func analyzePADEmotion(from text: String, at date: Date = Date()) -> Emotion {
        var words = [String]()
        text.enumerateSubstrings(
            in: text.startIndex...,
            options: [.byWords, .localized]
        ) { substr, _, _, _ in
            if let w = substr {
                words.append(w.lowercased())
            }
        }
        
        var totalPleasure = 0.0
        var totalArousal = 0.0
        var totalDominance = 0.0
        var matchedWords = 0

        for word in words {
            if let padScores = LexiconCollection.padMap[String(word)] {
                totalPleasure += padScores.pleasure
                totalArousal += padScores.arousal
                totalDominance += padScores.dominance
                matchedWords += 1
                print("Word recognized: \(word)")
            }
            print("Word not recognized: \(word)")
        }

        guard matchedWords > 0 else {
            // Default neutral emotion if no words match
            return Emotion(pleasure: 0.0, arousal: 0.5, dominance: 0.5, label: .neutrality, timestamp: date)
        }

        // Average scores
        let avgPleasure = totalPleasure / Double(matchedWords)
        let avgArousal = totalArousal / Double(matchedWords)
        let avgDominance = totalDominance / Double(matchedWords)

        // Determine emotion label based on PAD scores
        let emotionLabel = EmotionLabel.from(pleasure: avgPleasure, arousal: avgArousal, dominance: avgDominance)

        return Emotion(
            pleasure: avgPleasure,
            arousal: avgArousal,
            dominance: avgDominance,
            label: emotionLabel,
            timestamp: date
        )
    }
}
