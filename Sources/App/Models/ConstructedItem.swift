import Vapor
import FluentPostgreSQL

final class ConstructedItem: PostgreSQLUUIDModel {
	var id: ConstructedItem.ID?
	var categoryID: Category.ID
	var userID: User.ID?
	var isFavorite: Bool
	
	init(id: ConstructedItem.ID? = nil,
		 categoryID: Category.ID,
		 userID: User.ID? = nil,
		 isFavorite: Bool = false) {
		self.id = id
		self.categoryID = categoryID
		self.userID = userID
		self.isFavorite = isFavorite
	}
}

extension ConstructedItem: Parameter {}
extension ConstructedItem: Content {}
extension ConstructedItem: Migration {}

extension ConstructedItem {
	var category: Parent<ConstructedItem, Category>? {
		return parent(\.categoryID)
	}
}

extension ConstructedItem {
	var categoryItems: Siblings<ConstructedItem, CategoryItem, ConstructedItemCategoryItem> { return siblings() }
}

extension ConstructedItem {
	var modifiers: Siblings<ConstructedItem, Modifier, ConstructedItemModifier> { return siblings() }
}

extension ConstructedItem {
	func totalPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
		return try categoryItems.query(on: conn).all().map { $0 as [Purchasable] }
		.and(modifiers.query(on: conn).all().map { $0 as [Purchasable] })
		.map { ($0 + $1).totalPrice }
	}
}
