import Vapor
import Fluent
import FluentPostgreSQL

final class UserController {
    private let verifier = UserRequestVerifier()
    private let squareAPIManager = SquareAPIManager()
    
    private lazy var dataEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        if #available(OSX 10.12, *) { encoder.dateEncodingStrategy = .iso8601 }
        return encoder
    }()
    
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
            try constructedItems.map { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }.flatten(on: req)
        }
    }
    
    private func getOutstandingOrders(_ req: Request) throws -> Future<[OutstandingOrder]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try $0.outstandingOrders.query(on: req).all() }
    }
    
    private func getPurchasedOrders(_ req: Request) throws -> Future<[PurchasedOrder]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { try $0.purchasedOrders.query(on: req).all() }
    }
    
    private func getCards(_ req: Request) throws -> Future<[CardResponseData]> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.flatMap { user in
            try self.squareAPIManager.retrieveCustomer(id: user.customerID, client: req.client())
                .map { $0.cards?.map(self.makeCardResponseData) ?? [] }
        }
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
                id: user.customerID,
                data: .init(
                    cardNonce: data.cardNonce,
                    billingAddress: .init(postalCode: data.postalCode)
                ),
                client: req.client()
            )
        }.map(makeCardResponseData)
    }
    
    private func createPurchasedOrder(_ req: Request, data: CreatePurchasedOrderRequestData) throws -> Future<PurchasedOrderResponseData> {
        return try verifier.verify(req).flatMap { uid in
            try req.parameters.next(User.self)
                .guard({ $0.uid == uid }, else: Abort(.unauthorized))
        }.and(OutstandingOrder.find(data.outstandingOrderID, on: req)
            .unwrap(or: Abort(.badRequest))).flatMap { user, outstandingOrder in
                let userID = try user.requireID()
                guard userID == outstandingOrder.userID else { throw Abort(.unauthorized) }
                return try self.charge(user: user, outstandingOrder: outstandingOrder, cardNonce: data.cardNonce, customerCardID: data.customerCardID, req: req)
                    .flatMap { try self.makePurchasedOrder(outstandingOrder: outstandingOrder, userID: user.requireID(), transaction: $0, conn: req).create(on: req) }
                    .flatMap { try self.createAndAttachPurchasedConstructedItems(from: outstandingOrder, to: $0, conn: req)
                        .then { self.detachItemsAndDelete(outstandingOrder, conn: req) }
                        .transform(to: $0) }
                    .flatMap { try self.makePurchasedOrderResponseData(purchasedOrder: $0, conn: req) }
                    .do { do { try SessionController.default.send(self.dataEncoder.encode($0)) } catch { print(error.localizedDescription) } }
            }
    }
    
    // MARK: - Helper Methods
    private func queryConstructedItems(user: User, req: Request) throws -> Future<[ConstructedItem]> {
        var databaseQuery = try user.constructedItems.query(on: req)
        if let reqQuery = try? req.query.decode(GetConstructedItemsRequestQueryData.self) {
            if let isFavorite = reqQuery.isFavorite {
                databaseQuery = databaseQuery.filter(\.isFavorite == isFavorite)
            }
        }
        return databaseQuery.all()
    }
    
    private func charge(user: User, outstandingOrder: OutstandingOrder, cardNonce: String? = nil, customerCardID: String? = nil, req: Request) throws -> Future<SquareTransaction> {
        let idempotencyKey = UUID().uuidString
        return try outstandingOrder.totalPrice(on: req).flatMap { totalPrice in
            let amount = totalPrice + self.makeTaxPrice(price: totalPrice)
            return try self.squareAPIManager.charge(
                locationID: squareLocationID,
                data: .init(idempotencyKey: idempotencyKey, amountMoney: .init(amount: amount, currency: .usd), cardNonce: cardNonce, customerCardID: customerCardID, customerID: user.customerID),
                client: req.client()
            )
        }
    }
    
    private func createAndAttachPurchasedConstructedItems(from outstandingOrder: OutstandingOrder, to purchasedOrder: PurchasedOrder, conn: DatabaseConnectable) throws -> Future<Void> {
        return try outstandingOrder.constructedItems.query(on: conn).alsoDecode(OutstandingOrderConstructedItem.self).all()
            .flatMap { result in
                try result.map { constructedItem, outstandingOrderConstructedItem in
                    try self.makePurchasedConstructedItem(constructedItem: constructedItem, outstandingOrderConstructedItem: outstandingOrderConstructedItem, purchasedOrder: purchasedOrder, conn: conn).create(on: conn)
                        .flatMap { try self.attachCategoryItems(from: constructedItem, to: $0, conn: conn) }
                }.flatten(on: conn)
            }
    }
    
    private func attachCategoryItems(from constructedItem: ConstructedItem, to purchasedConstructedItem: PurchasedConstructedItem, conn: DatabaseConnectable) throws -> Future<Void> {
        return try constructedItem.categoryItems.query(on: conn).all()
            .flatMap { categoryItems in
                categoryItems.map { categoryItem in
                    purchasedConstructedItem.categoryItems.attach(categoryItem, on: conn)
                        .flatMap { pivot in
                            pivot.paidPrice = categoryItem.price
                            return pivot.save(on: conn).transform(to: ())
                        }
                }.flatten(on: conn)
            }
    }
    
    private func detachItemsAndDelete(_ outstandingOrder: OutstandingOrder, conn: DatabaseConnectable) -> Future<Void> {
        return outstandingOrder.constructedItems.detachAll(on: conn)
            .then { outstandingOrder.delete(on: conn) }
    }
    
    private func makeTaxPrice(price: Int) -> Int {
        return Int((Double(price) * AppConstants.taxRateMultiplier).rounded())
    }
    
    private func makePurchasedOrder(outstandingOrder: OutstandingOrder, userID: User.ID, transaction: SquareTransaction, conn: DatabaseConnectable) throws -> Future<PurchasedOrder> {
        return try outstandingOrder.totalPrice(on: conn).map { totalPrice in
            PurchasedOrder(
                userID: userID,
                transactionID: transaction.id,
                totalPrice: totalPrice,
                paidTaxPrice: self.makeTaxPrice(price: totalPrice),
                purchasedDate: Date(),
                preparedForDate: outstandingOrder.preparedForDate,
                note: outstandingOrder.note
            )
        }
    }
    
    private func makePurchasedConstructedItem(constructedItem: ConstructedItem, outstandingOrderConstructedItem: OutstandingOrderConstructedItem, purchasedOrder: PurchasedOrder, conn: DatabaseConnectable) throws -> Future<PurchasedConstructedItem> {
        return try constructedItem.totalPrice(on: conn).map { totalPrice in
            try PurchasedConstructedItem(
                orderID: purchasedOrder.requireID(),
                constructedItemID: constructedItem.requireID(),
                quantity: outstandingOrderConstructedItem.quantity,
                totalPrice: totalPrice * outstandingOrderConstructedItem.quantity
            )
        }
    }
    
    private func makeConstructedItemResponseData(constructedItem: ConstructedItem, conn: DatabaseConnectable) throws -> Future<ConstructedItemResponseData> {
        return try constructedItem.name(on: conn)
            .and(constructedItem.description(on: conn))
            .and(constructedItem.totalPrice(on: conn)).map { result in
                let ((name, description), totalPrice) = result
                return try ConstructedItemResponseData(
                    id: constructedItem.requireID(),
                    categoryID: constructedItem.categoryID,
                    userID: constructedItem.userID,
                    name: name,
                    description: description,
                    totalPrice: totalPrice,
                    isFavorite: constructedItem.isFavorite
                )
        }
    }
    
    private func makeCardResponseData(card: SquareCard) -> CardResponseData {
        return CardResponseData(
            id: card.id,
            name: card.cardBrand.name + " " + card.last4
        )
    }
    
    private func makePurchasedOrderResponseData(purchasedOrder: PurchasedOrder, conn: DatabaseConnectable) throws -> Future<PurchasedOrderResponseData> {
        return purchasedOrder.user.get(on: conn).map { user in
            try PurchasedOrderResponseData(
                id: purchasedOrder.requireID(),
                number: purchasedOrder.number,
                purchasedDate: purchasedOrder.purchasedDate,
                preparedForDate: purchasedOrder.preparedForDate,
                progress: purchasedOrder.progress,
                user: user
            )
        }
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
        // GET /users/:user/purchasedOrders
        usersRouter.get(User.parameter, "purchasedOrders", use: getPurchasedOrders)
        // GET /users/:user/cards
        usersRouter.get(User.parameter, "cards", use: getCards)
        
        // POST /users
        usersRouter.post(CreateUserRequestData.self, use: create)
        // POST /users/:user/cards
        usersRouter.post(CreateCardRequestData.self, at: User.parameter, "cards", use: createCard)
        // POST /users/:user/purchasedOrders
        usersRouter.post(CreatePurchasedOrderRequestData.self, at: User.parameter, "purchasedOrders", use: createPurchasedOrder)
    }
}

private extension UserController {
    struct GetConstructedItemsRequestQueryData: Codable {
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
        let postalCode: String
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
        let name: String
        let description: String
        let totalPrice: Int
        let isFavorite: Bool
    }
    
    struct CardResponseData: Content {
        let id: SquareCard.ID
        let name: String
    }
    
    struct PurchasedOrderResponseData: Content {
        let id: PurchasedOrder.ID
        let number: Int?
        let purchasedDate: Date
        let preparedForDate: Date?
        let progress: OrderProgress
        let user: User
    }
}
