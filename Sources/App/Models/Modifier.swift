import Vapor
import FluentPostgreSQL

final class Modifier: PostgreSQLUUIDModel {
    var id: Modifier.ID?
    var name: String
    var price: Int?
    var parentCategoryItemID: CategoryItem.ID?
}

extension Modifier: Purchasable {}
extension Modifier: Content {}
extension Modifier: Parameter {}
extension Modifier: Migration {}

extension Modifier {
    var parentCategoryItem: Parent<Modifier, CategoryItem>? {
        return parent(\.parentCategoryItemID)
    }
}
