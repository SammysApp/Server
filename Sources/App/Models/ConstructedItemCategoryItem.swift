import Vapor
import FluentPostgreSQL

final class ConstructedItemCategoryItem: PostgreSQLUUIDModel, ModifiablePivot {
	typealias Left = ConstructedItem
	typealias Right = CategoryItem
	
	static let name = "CategoryItem_ConstructedItem"
	
	static let leftIDKey: LeftIDKey = \.constructedItemID
	static let rightIDKey: RightIDKey = \.categoryItemID
	
	var id: ConstructedItemCategoryItem.ID?
	var constructedItemID: ConstructedItem.ID
	var categoryItemID: CategoryItem.ID
	
	init(_ constructedItem: ConstructedItem, _ categoryItem: CategoryItem) throws {
		self.constructedItemID = try constructedItem.requireID()
		self.categoryItemID = try categoryItem.requireID()
	}
}

extension ConstructedItemCategoryItem: Migration {}
