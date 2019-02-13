import Vapor
import FluentPostgreSQL

final class OutstandingOrder: PostgreSQLUUIDModel {
	var id: OutstandingOrder.ID?
	var userID: User.ID?
	
	init(id: OutstandingOrder.ID? = nil,
		 userID: User.ID? = nil) {
		self.id = id
		self.userID = userID
	}
}

extension OutstandingOrder: Parameter {}
extension OutstandingOrder: Content {}
extension OutstandingOrder: Migration {}

extension OutstandingOrder {
	var constructedItems: Siblings<OutstandingOrder, ConstructedItem, OutstandingOrderConstructedItem> { return siblings() }
}

extension OutstandingOrder {
	func pivot(attaching constructedItem: ConstructedItem, on conn: DatabaseConnectable) throws -> Future<OutstandingOrderConstructedItem?> {
		return try constructedItems.pivots(on: conn)
			.filter(\.outstandingOrderID == requireID())
			.filter(\.constructedItemID == constructedItem.requireID())
			.first()
	}
}
