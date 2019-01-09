import Vapor
import FluentPostgreSQL

final class Category: PostgreSQLUUIDModel {
	var id: Category.ID?
	var name: String
	var parentID: Category.ID?
	
	init(id: Category.ID? = nil, name: String, parentID: Category.ID? = nil) {
		self.id = id
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

extension Category {
	var items: Siblings<Category, Item, CategoryItem> { return siblings() }
}
