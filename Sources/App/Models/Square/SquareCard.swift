import Foundation

struct SquareCard: Codable {
    typealias ID = String
    
    let id: ID
    let cardBrand: SquareCardBrand
    let last4: String
}
