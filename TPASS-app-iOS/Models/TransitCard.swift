import Foundation
import SwiftData

@Model
final class TransitCard {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: TransitCardType
    var initialBalance: Int
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, type: TransitCardType = .custom, initialBalance: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
        self.createdAt = createdAt
    }
}
