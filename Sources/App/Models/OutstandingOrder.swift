import Vapor
import FluentPostgreSQL

final class OutstandingOrder: PostgreSQLUUIDModel {
	var id: OutstandingOrder.ID?
	var userID: User.ID?
}

extension OutstandingOrder: Parameter {}
extension OutstandingOrder: Content {}
extension OutstandingOrder: Migration {}

extension OutstandingOrder {
	var constructedItems: Siblings<OutstandingOrder, ConstructedItem, OutstandingOrderConstructedItem> { return siblings() }
}
