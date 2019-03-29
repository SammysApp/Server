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
        }.flatMap { try self.queryConstructedItems(user: $0, req: req) }.flatMap { constructedItems in
            try constructedItems.map { constructedItem in
                try constructedItem.totalPrice(on: req).map { try ConstructedItemData(constructedItem: constructedItem, totalPrice: $0) }
            }.flatten(on: req)
        }
    }
    
    private func getOutstandingOrders(_ req: Request) throws -> Future<[OutstandingOrder]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try $0.outstandingOrders.query(on: req).all() }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateData) throws -> Future<User> {
        return try verifier.verify(req).flatMap { uid in
            try self.squareAPIManager.createCustomer(data: .init(givenName: data.firstName, familyName: data.lastName, emailAddress: data.email), client: req.client()).and(result: uid)
        }.flatMap { User(uid: $1, customerID: $0.id, email: data.email, firstName: data.firstName, lastName: data.lastName).create(on: req) }
    }
    
    private func createCard(_ req: Request, data: CreateCardData) throws -> Future<CardData> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try self.squareAPIManager.createCustomerCard(customerID: $0.customerID, data: .init(cardNonce: data.cardNonce), client: req.client()) }.map(CardData.init)
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
                    data: .init(idempotencyKey: UUID().uuidString, amountMoney: .init(amount: totalPrice, currency: .usd), cardNonce: data.cardNonce, customerCardID: data.customerCardID, customerID: user.customerID),
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
        // POST /users/:user/cards
        usersRouter.post(CreateCardData.self, at: User.parameter, "cards", use: createCard)
        // POST /users/:user/purchasedOrders
        usersRouter.post(CreatePurchasedOrderData.self, at: User.parameter, "purchasedOrders", use: createPurchasedOrder)
    }
}

private extension UserController {
    struct ConstructedItemsQuery: Codable {
        let isFavorite: Bool?
    }
}

private extension UserController {
    struct ConstructedItemData: Content {
        let id: ConstructedItem.ID
        let categoryID: Category.ID
        let userID: User.ID?
        let totalPrice: Int
        let isFavorite: Bool
        
        init(constructedItem: ConstructedItem, totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.isFavorite = constructedItem.isFavorite
            self.totalPrice = totalPrice
        }
    }
    
    struct CardData: Content {
        let id: SquareCard.ID
        
        init(card: SquareCard) {
            self.id = card.id
        }
    }
}

private extension UserController {
    struct CreateData: Content {
        let email: String
        let firstName: String
        let lastName: String
    }
    
    struct CreateCardData: Content {
        let cardNonce: String
    }
    
    struct CreatePurchasedOrderData: Content {
        let outstandingOrderID: OutstandingOrder.ID
        let cardNonce: String?
        let customerCardID: String?
    }
}
