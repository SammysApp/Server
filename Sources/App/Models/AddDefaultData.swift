import Vapor
import FluentPostgreSQL

struct AddDefaultData: PostgreSQLMigration {
	static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
		return .done(on: conn)
	}
	
	static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
		return .done(on: conn)
	}
}
