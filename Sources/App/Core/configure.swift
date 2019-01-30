import Vapor
import FluentPostgreSQL
import Stripe

/// Called before application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	try services.register(FluentPostgreSQLProvider())
	
    // Register routes to the router.
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware.
    var middlewares = MiddlewareConfig()
	middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
	
	var commandConfig = CommandConfig.default()
	commandConfig.useFluentCommands()
	services.register(commandConfig)
	
	// Configure PostgreSQL database.
	let postgresConfig = PostgreSQLDatabaseConfig(
		hostname: AppConstants.PostgreSQL.hostname,
		port: AppConstants.PostgreSQL.port,
		username: AppConstants.PostgreSQL.username,
		database: AppConstants.PostgreSQL.database,
		password: AppSecrets.PostgreSQL.password
	)
	let postgres = PostgreSQLDatabase(config: postgresConfig)
	
	// Configure databases.
	var databases = DatabasesConfig()
	databases.add(database: postgres, as: .psql)
	services.register(databases)
	
	// Configure Stripe.
	let stripeCofig = StripeConfig(
		productionKey: AppSecrets.Stripe.liveKey,
		testKey: AppSecrets.Stripe.testKey
	)
	services.register(stripeCofig)
	try services.register(StripeProvider())
	
	// Configure migrations.
	var migrations = MigrationConfig()
	
	migrations.add(model: Category.self, database: .psql)
	migrations.add(model: Item.self, database: .psql)
	migrations.add(model: CategoryItem.self, database: .psql)
	migrations.add(model: Modifier.self, database: .psql)
	migrations.add(migration: AddDefaultData.self, database: .psql)
	
	migrations.add(model: ConstructedItem.self, database: .psql)
	migrations.add(model: ConstructedItemCategoryItem.self, database: .psql)
	
	services.register(migrations)
}
