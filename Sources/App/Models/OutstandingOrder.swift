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
