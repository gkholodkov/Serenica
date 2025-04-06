import Foundation

struct Memory {
    var personality: PersonalityProfile?
    var knowledge: [Fact]
    var emotionalState: [Emotion]
    var todaysEmotion: Emotion?
    
    init() {
        self.personality = nil
        self.knowledge = []
        self.emotionalState = []
        self.todaysEmotion = nil
    }
    
    init (personality: PersonalityProfile?, knowledge: [Fact], emotionalState: [Emotion], todaysEmotion: Emotion?) {
        self.personality = personality
        self.knowledge = knowledge
        self.emotionalState = emotionalState
        self.todaysEmotion = todaysEmotion
    }
}
