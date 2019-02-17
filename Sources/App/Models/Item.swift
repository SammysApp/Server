import Vapor
import FluentPostgreSQL

final class Item: PostgreSQLUUIDModel {
    var id: Item.ID?
    var name: String
    
    init(id: Item.ID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

extension Item: Content {}
extension Item: Parameter {}
extension Item: Migration {}

extension Item {
    var parentCategories: Siblings<Item, Category, CategoryItem> { return siblings() }
}
