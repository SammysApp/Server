import Vapor
import FluentPostgreSQL

final class UserController {
    private let verifier = UserRequestVerifier()
    private let squareAPIManager = SquareAPIManager()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<User> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }
    }
    
    private func getTokenUser(_ req: Request) throws -> Future<User> {
        return try verifier.verify(req).flatMap { uid in
            User.query(on: req).filter(\.uid == uid).first()
                .unwrap(or: Abort(.badRequest))
        }
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[ConstructedItemData]> {
        return try verifier.verify(req).flatMap { uid in
                try req.parameters.next(User.self)
                    .guard({ $0.uid == uid }, else: Abort(.unauthorized))
            }.flatMap { try self.queryConstructedItems(user: $0, req: req) }
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
        return try verifier.verify(req).flatMap {
                try self.squareAPIManager.createCustomer(data: SquareAPIManager.CreateCustomerRequestData(givenName: data.firstName, familyName: data.lastName, emailAddress: data.email), client: req.client())
                    .and(result: $0)
            }.flatMap { User(uid: $1, customerID: $0.id, email: data.email, firstName: data.firstName, lastName: data.lastName).create(on: req) }
    }
    
    private func createPurchasedOrder(_ req: Request, data: CreatePurchasedOrderData) throws -> Future<PurchasedOrder> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.and(OutstandingOrder.find(data.outstandingOrderID, on: req).unwrap(or: Abort(.badRequest))).flatMap { user, outstandingOrder in
            let userID = try user.requireID()
            guard userID == outstandingOrder.userID else { throw Abort(.unauthorized) }
            return try outstandingOrder.totalPrice(on: req).flatMap { totalPrice in
                return try self.squareAPIManager.charge(
                    locationID: AppConstants.Square.locationID,
                    data: SquareAPIManager.ChargeRequestData(idempotencyKey: UUID().uuidString, amountMoney: .init(amount: totalPrice, currency: .usd), cardNonce: data.cardNonce, customerCardID: data.customerCardID, customerID: user.customerID),
                    client: req.client()
                ).flatMap { transaction in
                    return self.makePurchasedOrder(outstandingOrder: outstandingOrder, userID: userID, transactionID: transaction.id, totalPrice: totalPrice)
                        .create(on: req)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
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
    
    private func makePurchasedOrder(outstandingOrder: OutstandingOrder, userID: User.ID, transactionID: SquareTransaction.ID, totalPrice: Int) -> PurchasedOrder {
        return PurchasedOrder(
            userID: userID,
            transactionID: transactionID,
            totalPrice: totalPrice,
            purchasedDate: Date(),
            preparedForDate: outstandingOrder.preparedForDate,
            note: outstandingOrder.note
        )
    }
}

extension UserController: RouteCollection {
    func boot(router: Router) throws {
        let usersRouter = router.grouped("\(AppConstants.version)/users")
        
        // GET /users/:user
        usersRouter.get(User.parameter, use: getOne)
        // GET /users/tokenUser
        usersRouter.get("tokenUser", use: getTokenUser)
        // GET /users/:user/constructedItems
        usersRouter.get(User.parameter, "constructedItems", use: getConstructedItems)
        // GET /users/:user/outstandingOrders
        usersRouter.get(User.parameter, "outstandingOrders", use: getOutstandingOrders)
        
        // POST /users
        usersRouter.post(CreateData.self, use: create)
        // POST /users/:user/purchasedOrders
        usersRouter.post(CreatePurchasedOrderData.self, use: createPurchasedOrder)
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
        var totalPrice: Int
        var isFavorite: Bool
        
        init(constructedItem: ConstructedItem, totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.isFavorite = constructedItem.isFavorite
            self.totalPrice = totalPrice
        }
    }
}

private extension UserController {
    struct CreateData: Content {
        let email: String
        let firstName: String
        let lastName: String
    }
    
    struct CreatePurchasedOrderData: Content {
        let outstandingOrderID: OutstandingOrder.ID
        let cardNonce: String?
        let customerCardID: String?
    }
}
