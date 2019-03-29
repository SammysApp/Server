import Vapor
import FluentPostgreSQL

enum OrderProgress: String, PostgreSQLEnum {
    case isPending, isPreparing, isCompleted
}

extension OrderProgress: PostgreSQLMigration {}
