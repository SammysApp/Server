import Vapor
import FluentPostgreSQL

enum OrderProgress: String, PostgreSQLEnum {
    case isPending, isInProgress, isCompleted
}

extension OrderProgress: PostgreSQLMigration {}
