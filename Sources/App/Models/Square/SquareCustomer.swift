import Foundation

struct SquareCustomer: Codable {
    typealias ID = String
    
    let id: ID
    let cards: [SquareCard]?
}
