import Vapor
import FluentPostgreSQL

final class ConstructedItemCategoryItem: PostgreSQLUUIDModel, ModifiablePivot {
	typealias Left = ConstructedItem
	typealias Right = CategoryItem
	
	static let name = "ConstructedItem_CategoryItem"
	
	static let leftIDKey: LeftIDKey = \.constructedItemID
	static let rightIDKey: RightIDKey = \.categoryItemID
	
	var id: ConstructedItemCategoryItem.ID?
	var constructedItemID: ConstructedItem.ID
	var categoryItemID: CategoryItem.ID
	
	init(_ left: Left, _ right: Right) throws {
		self.constructedItemID = try left.requireID()
		self.categoryItemID = try right.requireID()
	}
}

extension ConstructedItemCategoryItem: Migration {}
