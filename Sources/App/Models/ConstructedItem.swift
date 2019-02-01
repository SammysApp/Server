import Vapor
import FluentPostgreSQL

final class ConstructedItem: PostgreSQLUUIDModel {
	var id: ConstructedItem.ID?
	var parentCategoryID: Category.ID?
	
	init(id: ConstructedItem.ID? = nil, parentCategoryID: Category.ID? = nil) {
		self.id = id
		self.parentCategoryID = parentCategoryID
	}
}

extension ConstructedItem: Migration {}

extension ConstructedItem {
	var parentCategory: Parent<ConstructedItem, Category>? {
		return parent(\.parentCategoryID)
	}
}

extension ConstructedItem {
	var categoryItems: Siblings<ConstructedItem, CategoryItem, ConstructedItemCategoryItem> { return siblings() }
}

extension ConstructedItem {
	var modifiers: Siblings<ConstructedItem, Modifier, ConstructedItemModifier> { return siblings() }
}
