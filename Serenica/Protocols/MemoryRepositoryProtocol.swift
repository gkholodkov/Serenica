import Foundation
import CoreData

protocol MemoryRepositoryProtocol {
    func createMemory()
    func fetchMemory() -> Memory
    func updateMemory(_ memory: Memory)
    func clearMemory()
}
