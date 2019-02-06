import Vapor
import FluentPostgreSQL

final class User: PostgreSQLUUIDModel {
	typealias UID = String
	
	var id: User.ID?
	var uid: UID
}

extension User: Parameter {}
extension User: Content {}
extension User: Migration {}

extension User {
	var constructedItems: Children<User, ConstructedItem> {
		return children(\.userID)
	}
}
