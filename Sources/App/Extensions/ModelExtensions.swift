import Vapor
import Fluent
import MongoSwift

extension Model where ID == UUID {
	func asBinary() throws -> Binary { return try Binary(from: requireID()) }
}
