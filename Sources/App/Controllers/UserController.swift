import Vapor
import Fluent
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
    
    private func getConstructedItems(_ req: Request) throws -> Future<[ConstructedItemResponseData]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try self.queryConstructedItems(user: $0, req: req) }.flatMap { constructedItems in
            try constructedItems.map { try self.makeConstructedItemResponseData(constructedItem: $0, req: req) }.flatten(on: req)
        }
    }
    
    private func getOutstandingOrders(_ req: Request) throws -> Future<[OutstandingOrder]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try $0.outstandingOrders.query(on: req).all() }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateUserRequestData) throws -> Future<User> {
        return try verifier.verify(req).flatMap { uid in
            try self.squareAPIManager.createCustomer(data: .init(
                givenName: data.firstName,
                familyName: data.lastName,
                emailAddress: data.email
            ), client: req.client()).and(result: uid)
        }.flatMap { customer, uid in
            User(uid: uid, customerID: customer.id, email: data.email, firstName: data.firstName, lastName: data.lastName)
                .create(on: req)
        }
    }
    
    private func createCard(_ req: Request, data: CreateCardRequestData) throws -> Future<CardResponseData> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { user in
            try self.squareAPIManager.createCustomerCard(
                customerID: user.customerID,
                data: .init(cardNonce: data.cardNonce),
                client: req.client()
            )
        }.map { CardResponseData(id: $0.id) }
    }
    
    private func createPurchasedOrder(_ req: Request, data: CreatePurchasedOrderRequestData) throws -> Future<PurchasedOrder> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.and(OutstandingOrder.find(data.outstandingOrderID, on: req).unwrap(or: Abort(.badRequest))).flatMap { user, outstandingOrder in
            let userID = try user.requireID()
            guard userID == outstandingOrder.userID else { throw Abort(.unauthorized) }
            return try outstandingOrder.totalPrice(on: req).flatMap { totalPrice in
                return try self.squareAPIManager.charge(
                    locationID: AppConstants.Square.locationID,
                    // Setting the outstanding order's id as the idempotency key will prevent the user being charged again for this order in case this is called more than once.
                    data: .init(idempotencyKey: outstandingOrder.requireID().uuidString, amountMoney: .init(amount: totalPrice, currency: .usd), cardNonce: data.cardNonce, customerCardID: data.customerCardID, customerID: user.customerID),
                    client: req.client()
                ).flatMap { transaction in
                    return self.makePurchasedOrder(outstandingOrder: outstandingOrder, userID: userID, transaction: transaction, totalPrice: totalPrice)
                        .create(on: req)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func queryConstructedItems(user: User, req: Request) throws -> Future<[ConstructedItem]> {
        var databaseQuery = try user.constructedItems.query(on: req)
        if let requestQuery = try? req.query.decode(GetConstructedItemsQueryData.self) {
            if let isFavorite = requestQuery.isFavorite {
                databaseQuery = databaseQuery.filter(\.isFavorite == isFavorite)
            }
        }
        return databaseQuery.all()
    }
    
    private func makeConstructedItemResponseData(constructedItem: ConstructedItem, req: Request) throws -> Future<ConstructedItemResponseData> {
        return try constructedItem.totalPrice(on: req).map { totalPrice in
            return try ConstructedItemResponseData(
                id: constructedItem.requireID(),
                categoryID: constructedItem.categoryID,
                userID: constructedItem.userID,
                totalPrice: totalPrice,
                isFavorite: constructedItem.isFavorite
            )
        }
    }
    
    private func makePurchasedOrder(outstandingOrder: OutstandingOrder, userID: User.ID, transaction: SquareTransaction, totalPrice: Int) -> PurchasedOrder {
        return PurchasedOrder(
            userID: userID,
            transactionID: transaction.id,
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
        usersRouter.post(CreateUserRequestData.self, use: create)
        // POST /users/:user/cards
        usersRouter.post(CreateCardRequestData.self, at: User.parameter, "cards", use: createCard)
        // POST /users/:user/purchasedOrders
        usersRouter.post(CreatePurchasedOrderRequestData.self, at: User.parameter, "purchasedOrders", use: createPurchasedOrder)
    }
}

private extension UserController {
    struct GetConstructedItemsQueryData: Codable {
        let isFavorite: Bool?
    }
}

private extension UserController {
    struct CreateUserRequestData: Content {
        let email: String
        let firstName: String
        let lastName: String
    }
    
    struct CreateCardRequestData: Content {
        let cardNonce: String
    }
    
    struct CreatePurchasedOrderRequestData: Content {
        let outstandingOrderID: OutstandingOrder.ID
        let cardNonce: String?
        let customerCardID: String?
    }
}

private extension UserController {
    struct ConstructedItemResponseData: Content {
        let id: ConstructedItem.ID
        let categoryID: Category.ID
        let userID: User.ID?
        let totalPrice: Int
        let isFavorite: Bool
    }
    
    struct CardResponseData: Content {
        let id: SquareCard.ID
    }
}
