import Vapor
import FluentPostgreSQL

final class Modifier: PostgreSQLUUIDModel {
    var id: Modifier.ID?
    var categoryItemID: CategoryItem.ID
    var name: String
    var price: Int?
    var availability: Availability
    
    init(id: Modifier.ID? = nil,
         categoryItemID: CategoryItem.ID,
         name: String,
         price: Int? = nil,
         availability: Availability = .isAvailable) {
        self.id = id
        self.categoryItemID = categoryItemID
        self.name = name
        self.price = price
        self.availability = availability
    }
}

extension Modifier: Purchasable {}
extension Modifier: Content {}
extension Modifier: Parameter {}
extension Modifier: Migration {}

extension Modifier {
    var parentCategoryItem: Parent<Modifier, CategoryItem>? {
        return parent(\.categoryItemID)
    }
}
