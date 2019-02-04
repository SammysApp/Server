import Vapor
import FluentPostgreSQL

final class User: PostgreSQLUUIDModel {
	typealias UID = String
	
	var id: User.ID?
	var uid: UID
}

extension User: Parameter {}
extension User: Migration {}
