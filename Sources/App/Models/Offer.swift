import Vapor
import FluentPostgreSQL

final class Offer: PostgreSQLUUIDModel {
    var id: Offer.ID?
    var code: String
    var name: String?
    var discountPrice: Int?
    var discountPercent: Int?
    var availability: Availability
    
    init(id: Offer.ID? = nil,
         code: String,
         name: String? = nil,
         discountPrice: Int? = nil,
         discountPercent: Int? = nil,
         availability: Availability = .isAvailable) {
        self.id = id
        self.code = code
        self.name = name
        self.discountPrice = discountPrice
        self.discountPercent = discountPercent
        self.availability = availability
    }
}

extension Offer: Migration {}
