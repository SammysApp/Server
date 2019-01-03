import Vapor
import FluentPostgreSQL

/// Called before application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	try services.register(FluentPostgreSQLProvider())
	
    /// Register routes to the router.
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware.
    var middlewares = MiddlewareConfig()
	middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
	
	let postgresConfig = PostgreSQLDatabaseConfig(hostname: "localhost", port: 5432, username: "natanel", database: "")
	let postgres = PostgreSQLDatabase(config: postgresConfig)
	
	var databases = DatabasesConfig()
	databases.add(database: postgres, as: .psql)
	services.register(databases)
	
	var migrations = MigrationConfig()
	services.register(migrations)
}
