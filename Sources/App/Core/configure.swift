import Vapor
import FluentPostgreSQL

let squareAccessToken: String = Environment.get(.squareAccessToken) ?? preconditionFailure(EnvironmentError.missingEnvironmentVariables.localizedDescription)

let squareLocationID: String = Environment.get(.squareLocationID) ?? preconditionFailure(EnvironmentError.missingEnvironmentVariables.localizedDescription)

/// Called before application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register routes to the router.
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    // Register sockets to the server.
    let socketServer = NIOWebSocketServer.default()
    sockets(socketServer)
    services.register(socketServer, as: WebSocketServer.self)
    
    // Register middleware.
    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
    
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)
    
    try services.register(FluentPostgreSQLProvider())
    
    // Configure PostgreSQL database.
    guard let postgreSQLHostname = Environment.get(.postgreSQLHostname),
        let postgreSQLDatabase = Environment.get(.postgreSQLDatabase),
        let postgreSQLUsername = Environment.get(.postgreSQLUsername)
        else { throw EnvironmentError.missingEnvironmentVariables }
    
    var postgreSQLPort = AppConstants.PostgreSQL.defaultPort
    if let envPostgreSQLPortString = Environment.get(.postgreSQLPort),
        let envPostgreSQLPort = Int(envPostgreSQLPortString) {
        postgreSQLPort = envPostgreSQLPort
    }
    
    let postgresConfig = PostgreSQLDatabaseConfig(
        hostname: postgreSQLHostname,
        port: postgreSQLPort,
        username: postgreSQLUsername,
        database: postgreSQLDatabase,
        password: Environment.get(.postgreSQLPassword)
    )
    let postgres = PostgreSQLDatabase(config: postgresConfig)
    
    // Configure databases.
    var databases = DatabasesConfig()
    databases.add(database: postgres, as: .psql)
    services.register(databases)
    
    // Configure migrations.
    var migrations = MigrationConfig()
    
    migrations.add(migration: Availability.self, database: .psql)
    migrations.add(migration: OrderProgress.self, database: .psql)
    
    migrations.add(model: StoreHours.self, database: .psql)
    migrations.add(model: Category.self, database: .psql)
    migrations.add(model: Item.self, database: .psql)
    migrations.add(model: CategoryItem.self, database: .psql)
    migrations.add(model: Modifier.self, database: .psql)
    migrations.add(model: Offer.self, database: .psql)
    
    migrations.add(model: ConstructedItem.self, database: .psql)
    migrations.add(model: ConstructedItemCategoryItem.self, database: .psql)
    migrations.add(model: ConstructedItemModifier.self, database: .psql)
    migrations.add(model: OutstandingOrder.self, database: .psql)
    migrations.add(model: OutstandingOrderConstructedItem.self, database: .psql)
    migrations.add(model: OutstandingOrderOffer.self, database: .psql)
    migrations.add(model: PurchasedOrder.self, database: .psql)
    migrations.add(model: PurchasedConstructedItem.self, database: .psql)
    migrations.add(model: PurchasedConstructedItemCategoryItem.self, database: .psql)
    migrations.add(model: PurchasedOrderOffer.self, database: .psql)
    migrations.add(model: User.self, database: .psql)
    
    migrations.add(migration: AddDefaultData.self, database: .psql)
    
    services.register(migrations)
}
