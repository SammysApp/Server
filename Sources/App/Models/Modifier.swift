import Vapor
import FluentPostgreSQL

final class Modifier: PostgreSQLUUIDModel {
	var id: Modifier.ID?
	let name: String
	let price: Double?
	var parentCategoryItemID: CategoryItem.ID?
}

extension Modifier: Content {}
extension Modifier: Parameter {}
extension Modifier: Migration {}

extension Modifier {
	var parentCategoryItem: Parent<Modifier, CategoryItem>? {
		return parent(\.parentCategoryItemID)
	}
}
