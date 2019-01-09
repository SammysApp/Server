import Vapor
import FluentPostgreSQL

final class CategoryItem: PostgreSQLUUIDPivot, ModifiablePivot {
	typealias Left = Category
	typealias Right = Item
	
	static let leftIDKey: LeftIDKey = \.categoryID
	static let rightIDKey: RightIDKey = \.itemID
	
	var id: UUID?
	var categoryID: Category.ID
	var itemID: Item.ID
	
	init(_ category: Category, _ item: Item) throws {
		self.categoryID = try category.requireID()
		self.itemID = try item.requireID()
	}
}

extension CategoryItem: Migration {}
