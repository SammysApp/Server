import Vapor
import FluentPostgreSQL

final class User: PostgreSQLUUIDModel {
	typealias UID = String
	
	var id: User.ID?
	var uid: UID
	
	init(id: User.ID? = nil, uid: UID) {
		self.id = id
		self.uid = uid
	}
}

extension User: Parameter {}
extension User: Content {}
extension User: Migration {}

extension User {
	var constructedItems: Children<User, ConstructedItem> {
		return children(\.userID)
	}
}

extension User {
	var outstandingOrders: Children<User, OutstandingOrder> {
		return children(\.userID)
	}
}
