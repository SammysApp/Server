import Vapor
import FluentPostgreSQL

enum Availability: String, PostgreSQLEnum {
    case isAvailable, isTemporarilyUnavailable, isUnavailable
}

extension Availability: PostgreSQLMigration {}
