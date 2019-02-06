import Vapor
import FluentPostgreSQL

final class Category: PostgreSQLUUIDModel {
	var id: Category.ID?
	var name: String
	var parentCategoryID: Category.ID?
	var isConstructable: Bool
	
	init(id: Category.ID? = nil,
		 name: String,
		 parentCategoryID: Category.ID? = nil,
		 isConstructable: Bool = false) {
		self.id = id
		self.name = name
		self.parentCategoryID = parentCategoryID
		self.isConstructable = isConstructable
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

extension Category {
	var constructedItems: Children<Category, ConstructedItem> {
		return children(\.parentCategoryID)
	}
}

extension Category {
	func pivot(attaching item: Item, on conn: DatabaseConnectable) throws -> Future<CategoryItem?> {
		return try items.pivots(on: conn)
			.filter(\.categoryID == requireID())
			.filter(\.itemID == item.requireID())
			.first()
	}
}

extension Category: Equatable {
	static func == (lhs: Category, rhs: Category) -> Bool {
		do { return try lhs.requireID() == rhs.requireID() } catch { return false }
	}
}
