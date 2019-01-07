import Vapor
import FluentPostgreSQL

final class Category: PostgreSQLUUIDModel {
	var id: UUID?
	var name: String
	var parentID: Category.ID?
	
	init(name: String, parentID: Category.ID? = nil) {
		self.name = name
		self.parentID = parentID
	}
}

extension Category: Content {}
extension Category: Parameter {}
extension Category: Migration {}

extension Category {
	var parentCategory: Parent<Category, Category>? {
		return parent(\.parentID)
	}
	
	var subcategories: Children<Category, Category> {
		return children(\.parentID)
	}
}
