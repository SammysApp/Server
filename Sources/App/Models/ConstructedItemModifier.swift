import Vapor
import FluentPostgreSQL

final class ConstructedItemModifier: PostgreSQLUUIDModel, ModifiablePivot {
	typealias Left = ConstructedItem
	typealias Right = Modifier
	
	static let leftIDKey: LeftIDKey = \.constructedItemID
	static let rightIDKey: RightIDKey = \.modifierID
	
	var id: ConstructedItemModifier.ID?
	var constructedItemID: ConstructedItem.ID
	var modifierID: Modifier.ID
	
	init(_ constructedItem: ConstructedItem, _ modifier: Modifier) throws {
		self.constructedItemID = try constructedItem.requireID()
		self.modifierID = try modifier.requireID()
	}
}

extension ConstructedItemModifier: Migration {}
