import Vapor
import FluentPostgreSQL

final class OutstandingOrderConstructedItem: PostgreSQLUUIDPivot, ModifiablePivot {
	typealias Left = OutstandingOrder
	typealias Right = ConstructedItem
	
	static let leftIDKey: LeftIDKey = \.outstandingOrderID
	static let rightIDKey: RightIDKey = \.constructedItemID
	
	var id: OutstandingOrderConstructedItem.ID?
	var outstandingOrderID: OutstandingOrder.ID
	var constructedItemID: ConstructedItem.ID
	
	init(_ outstandingOrder: OutstandingOrder, _ constructedItem: ConstructedItem) throws {
		self.outstandingOrderID = try outstandingOrder.requireID()
		self.constructedItemID = try constructedItem.requireID()
	}
}

extension OutstandingOrderConstructedItem: Migration {}

