// --- 3. Tests for the new logic

import XCTest
@testable import Serenica   // ← replace with your real module

final class EmotionAggregationTests: XCTestCase {

    /// Helper to build an Emotion with a given repeat count
    private func makeEmotion(
        pleasure: Double,
        arousal: Double,
        dominance: Double,
        secondsAgo: TimeInterval,
        occurrences: Int = 1
    ) -> Emotion {
        var e = Emotion(
            pleasure: pleasure,
            arousal: arousal,
            dominance: dominance,
            label: nil,
            timestamp: Date().addingTimeInterval(-secondsAgo)
        )
        e.consecutiveOccurrences = occurrences
        return e
    }

    func testWeightedModeLabel_occurrenceWeighting() {
        // Two sadness (each occ=1) vs one joy (occ=3):
        // purely by occurrences, joy should win
        let sadnesses = (0..<2).map { _ in
            makeEmotion(pleasure: -0.8, arousal: 0.1, dominance: 0.3, secondsAgo: 10, occurrences: 1)
        }
        let bigJoy = makeEmotion(pleasure: 0.8, arousal: 0.5, dominance: 0.5, secondsAgo: 10, occurrences: 3)

        let all = sadnesses + [bigJoy]
        let winner = all.weightedModeLabel(timeDecayLambda: 0.0, intensityAlpha: 0.0)
        XCTAssertEqual(winner, .joy,
                       "With pure occurrence weighting, joy (3 votes) should beat sadness (2 votes)")
    }

    func testWeightedModeLabel_combinedWeights() {
        // Joy with low intensity but many occurrences, vs
        // Sadness with high intensity but few occurrences.
        let nearJoy = makeEmotion(pleasure: 0.51, arousal: 0.51, dominance: 0.51,
                                  secondsAgo: 0, occurrences: 5)
        let farSad  = makeEmotion(pleasure: -1.0, arousal: 1.0, dominance: 1.0,
                                  secondsAgo: 0, occurrences: 1)

        // intensityAlpha=1 so farSad gets big dist weight, but joy's multiple occurrences should still win.
        let winner = [nearJoy, farSad]
            .weightedModeLabel(timeDecayLambda: 0.0, intensityAlpha: 1.0)
        XCTAssertEqual(winner, .joy,
                       "Even though sadness is far in its bucket, joy’s 5 occurrences should outvote it.")
    }
}

