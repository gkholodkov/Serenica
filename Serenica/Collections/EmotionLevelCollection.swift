import Foundation

struct EmotionLevelCollection {
    static let emotionMap: [ PADKey: EmotionLabel ] = [
        // High Pleasure
        PADKey(p: .High, a: .High, d: .High): .elation,
        PADKey(p: .High, a: .High, d: .Mid):  .exhilaration,
        PADKey(p: .High, a: .High, d: .Low):  .wonder,
        PADKey(p: .High, a: .Mid, d: .High): .pride,
        PADKey(p: .High, a: .Mid, d: .Mid):  .joy,
        PADKey(p: .High, a: .Mid, d: .Low):  .amusement,
        PADKey(p: .High, a: .Low, d: .High): .confidence,
        PADKey(p: .High, a: .Low, d: .Mid):  .contentment,
        PADKey(p: .High, a: .Low, d: .Low):  .serenity,
        
        // Mid Pleasure
        PADKey(p: .Mid, a: .High, d: .High): .vigilance,
        PADKey(p: .Mid, a: .High, d: .Mid):  .surprise,
        PADKey(p: .Mid, a: .High, d: .Low):  .startle,
        PADKey(p: .Mid, a: .Mid, d: .High): .interest,
        PADKey(p: .Mid, a: .Mid, d: .Mid):  .neutrality,
        PADKey(p: .Mid, a: .Mid, d: .Low):  .reflection,
        PADKey(p: .Mid, a: .Low, d: .High): .composure,
        PADKey(p: .Mid, a: .Low, d: .Mid):  .relaxation,
        PADKey(p: .Mid, a: .Low, d: .Low):  .boredom,

        // Low Pleasure
        PADKey(p: .Low, a: .High, d: .High): .rage,
        PADKey(p: .Low, a: .High, d: .Mid):  .anger,
        PADKey(p: .Low, a: .High, d: .Low):  .fear,
        PADKey(p: .Low, a: .Mid, d: .High): .contempt,
        PADKey(p: .Low, a: .Mid, d: .Mid):  .disgust,
        PADKey(p: .Low, a: .Mid, d: .Low):  .guilt,
        PADKey(p: .Low, a: .Low, d: .High): .regret,
        PADKey(p: .Low, a: .Low, d: .Mid):  .sadness,
        PADKey(p: .Low, a: .Low, d: .Low):  .despair,
    ]
}
