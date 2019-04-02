import Vapor
import FluentPostgreSQL

final class Item: PostgreSQLUUIDModel {
    var id: Item.ID?
    var name: String
    var availability: Availability
    
    init(id: Item.ID? = nil,
         name: String,
         availability: Availability = .isAvailable) {
        self.id = id
        self.name = name
        self.availability = availability
    }
}

extension Item: Content {}
extension Item: Parameter {}
extension Item: Migration {}

extension Item {
    var parentCategories: Siblings<Item, Category, CategoryItem> { return siblings() }
}
