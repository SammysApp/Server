import Vapor
import FluentPostgreSQL

final class Category: PostgreSQLUUIDModel {
	var id: Category.ID?
	var name: String
	var parentCategoryID: Category.ID?
	
	init(id: Category.ID? = nil, name: String, parentCategoryID: Category.ID? = nil) {
		self.id = id
		self.name = name
		self.parentCategoryID = parentCategoryID
	}
}

extension Category: Content {}
extension Category: Parameter {}
extension Category: Migration {}

extension Category {
	var parentCategory: Parent<Category, Category>? {
		return parent(\.parentCategoryID)
	}
	
	var subcategories: Children<Category, Category> {
		return children(\.parentCategoryID)
	}
}

extension Category {
	var items: Siblings<Category, Item, CategoryItem> { return siblings() }
}
