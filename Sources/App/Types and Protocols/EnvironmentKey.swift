import Vapor

enum EnvironmentKey: String {
    // MARK: - PostgreSQL
    case postgreSQLHostname = "POSTGRESQL_HOSTNAME"
    case postgreSQLPort = "POSTGRESQL_PORT"
    case postgreSQLDatabase = "POSTGRESQL_DATABASE"
    case postgreSQLUsername = "POSTGRESQL_USERNAME"
    case postgreSQLPassword = "POSTGRESQL_PASSWORD"
    
    // MARK: - SQUARE
    case squareAccessToken = "SQUARE_ACCESS_TOKEN"
    case squareLocationID = "SQUARE_LOCATION_ID"
}

extension Environment {
    static func get(_ key: EnvironmentKey) -> String? {
        return self.get(key.rawValue)
    }
}
