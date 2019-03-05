import Vapor
import FluentPostgreSQL
import Stripe

/// Called before application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
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
    
    try services.register(FluentPostgreSQLProvider())
    
    // Configure PostgreSQL database.
    let postgresConfig = PostgreSQLDatabaseConfig(
        hostname: LocalConstants.PostgreSQL.hostname,
        port: LocalConstants.PostgreSQL.port,
        username: LocalConstants.PostgreSQL.username,
        database: LocalConstants.PostgreSQL.database
    )
    let postgres = PostgreSQLDatabase(config: postgresConfig)
    
    // Configure databases.
    var databases = DatabasesConfig()
    databases.add(database: postgres, as: .psql)
    services.register(databases)
    
    // Configure migrations.
    var migrations = MigrationConfig()
    
    migrations.add(migration: OrderProgress.self, database: .psql)
    
    migrations.add(model: Category.self, database: .psql)
    migrations.add(model: Item.self, database: .psql)
    migrations.add(model: CategoryItem.self, database: .psql)
    migrations.add(model: Modifier.self, database: .psql)
    migrations.add(migration: AddDefaultData.self, database: .psql)
    
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: ConstructedItem.self, database: .psql)
    migrations.add(model: ConstructedItemCategoryItem.self, database: .psql)
    migrations.add(model: ConstructedItemModifier.self, database: .psql)
    migrations.add(model: OutstandingOrder.self, database: .psql)
    migrations.add(model: OutstandingOrderConstructedItem.self, database: .psql)
    migrations.add(model: PurchasedOrder.self, database: .psql)
    
    services.register(migrations)
    
    // Configure Stripe.
    let stripeCofig = StripeConfig(
        productionKey: AppSecrets.Stripe.liveKey,
        testKey: AppSecrets.Stripe.testKey
    )
    services.register(stripeCofig)
    try services.register(StripeProvider())
}
