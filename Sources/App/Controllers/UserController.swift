import Vapor
import FluentPostgreSQL
import Stripe

final class UserController {
    private let verifier = UserRequestVerifier()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(User.self)
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[ConstructedItemData]> {
        return try verifier.verify(req)
            .flatMap { uid in try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized)) }
            .flatMap { try self.queryConstructedItems(user: $0, req: req) }
            .flatMap { try $0.map { try self.makeConstructedItemData(constructedItem: $0, req: req) }.flatten(on: req) }
    }
    
    private func getOutstandingOrders(_ req: Request) throws -> Future<[OutstandingOrder]> {
        return try verifier.verify(req).flatMap { uid in
                try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized)) }
            .flatMap { try self.makeOutstandingOrders(user: $0, req: req) }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateData) throws -> Future<User> {
        return try verifier.verify(req)
            .and(self.stripeClient(req).customer.create(email: data.email))
            .flatMap { User(uid: $0, customerID: $1.id, email: data.email, name: data.name).create(on: req) }
    }
    
    // MARK: - Helper Methods
    private func stripeClient(_ req: Request) throws -> StripeClient {
        return try req.make(StripeClient.self)
    }
    
    private func queryConstructedItems(user: User, req: Request) throws -> Future<[ConstructedItem]> {
        var databaseQuery = try user.constructedItems.query(on: req)
        if let requestQuery = try? req.query.decode(ConstructedItemsQuery.self) {
            if let isFavorite = requestQuery.isFavorite {
                databaseQuery = databaseQuery.filter(\.isFavorite == isFavorite)
            }
        }
        return databaseQuery.all()
    }
    
    private func makeOutstandingOrders(user: User, req: Request) throws -> Future<[OutstandingOrder]> {
        return try user.outstandingOrders.query(on: req).all()
    }
    
    private func makeConstructedItemData(constructedItem: ConstructedItem, req: Request) throws -> Future<ConstructedItemData> {
        return try constructedItem.totalPrice(on: req)
            .map { try ConstructedItemData(constructedItem: constructedItem, totalPrice: $0) }
    }
}

extension UserController: RouteCollection {
    func boot(router: Router) throws {
        let usersRouter = router.grouped("\(AppConstants.version)/users")
        
        // GET /users/:user
        usersRouter.get(User.parameter, use: getOne)
        // GET /users/:user/constructedItems
        usersRouter.get(User.parameter, "constructedItems", use: getConstructedItems)
        // GET /users/:user/outstandingOrders
        usersRouter.get(User.parameter, "outstandingOrders", use: getOutstandingOrders)
        
        // POST /users
        usersRouter.post(CreateData.self, use: create)
    }
}

private extension UserController {
    struct CreateData: Content {
        let email: String
        let name: String
    }
}

private extension UserController {
    struct ConstructedItemsQuery: Codable {
        let isFavorite: Bool?
    }
}

private extension UserController {
    struct ConstructedItemData: Content {
        var id: ConstructedItem.ID
        var categoryID: Category.ID
        var userID: User.ID?
        var isFavorite: Bool
        var totalPrice: Int
        
        init(constructedItem: ConstructedItem, totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.isFavorite = constructedItem.isFavorite
            self.totalPrice = totalPrice
        }
    }
}
