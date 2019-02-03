import Vapor
import FluentPostgreSQL

final class User: PostgreSQLUUIDModel {
	var id: User.ID?
	var uid: String
}

extension User: Migration {}
