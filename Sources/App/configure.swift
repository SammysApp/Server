import Vapor
import FluentPostgreSQL
import MongoSwift
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
	
	// Configure PostgreSQL.
	let postgresConfig = PostgreSQLDatabaseConfig(
		hostname: AppConstants.PostgreSQL.hostname,
		port: AppConstants.PostgreSQL.port,
		username: AppConstants.PostgreSQL.username,
		database: AppConstants.PostgreSQL.database,
		password: AppSecrets.PostgreSQL.password
	)
	let postgres = PostgreSQLDatabase(config: postgresConfig)
	
	var databases = DatabasesConfig()
	databases.add(database: postgres, as: .psql)
	services.register(databases)
	
	// Configure MongoDB.
	MongoSwift.initialize()
	let client = try MongoClient(connectionString: AppConstants.MongoDB.connectionString)
	let mongoDatabase = try client.db(AppConstants.MongoDB.database)
	
	let currentCollections = Array(try mongoDatabase.listCollections())
	if !currentCollections.contains(named: AppConstants.MongoDB.categoryItemsCollection) {
		let collection = try mongoDatabase
			.createCollection(AppConstants.MongoDB.categoryItemsCollection)
		try collection.createIndex([
			CategoryItemDocument.CodingKeys.category.rawValue: 1,
			CategoryItemDocument.CodingKeys.item.rawValue: 1
		])
	}
	if !currentCollections.contains(named: AppConstants.MongoDB.metadataCollection) {
		let _ = try mongoDatabase
			.createCollection(AppConstants.MongoDB.metadataCollection)
	}
	
	try AddDefaultData.addMongoData(mongoDatabase)
	services.register(client)
	
	// Configure Stripe.
	let stripeCofig = StripeConfig(
		productionKey: AppSecrets.Stripe.liveKey,
		testKey: AppSecrets.Stripe.testKey
	)
	services.register(stripeCofig)
	try services.register(StripeProvider())
	
	var migrations = MigrationConfig()
	migrations.add(model: Category.self, database: .psql)
	migrations.add(model: Item.self, database: .psql)
	migrations.add(model: CategoryItem.self, database: .psql)
	migrations.add(migration: AddDefaultData.self, database: .psql)
	services.register(migrations)
}

extension MongoClient: Service {}

private extension Array where Element == Document {
	func contains(named name: String) -> Bool {
		return contains { $0["name"] as? String == name }
	}
}
