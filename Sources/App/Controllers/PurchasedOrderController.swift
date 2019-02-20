import Vapor
import FluentPostgreSQL
import MongoKitten
import Stripe

final class PurchasedOrderController {
    private let verifier = UserRequestVerifier()

    private enum CollectionNames: String, CollectionName {
        case purchasedOrders
    }

    // MARK: - POST
    private func create(_ req: Request, data: CreateData) throws -> Future<PurchasedOrder> {
        return try verifiedUser(data.userID, req: req)
            .and(OutstandingOrder.find(data.outstandingOrderID, on: req)
                .unwrap(or: Abort(.badRequest)))
            .guard({ $0.id == $1.userID }, else: Abort(.unauthorized))
            .flatMap { user, outstandingOrder in
                try outstandingOrder.totalPrice(on: req).flatMap { totalPrice in
                    try self.createCharge(for: totalPrice, user: user, source: data.source, req: req)
                        .flatMap { try self.makePurchasedOrder(user: user, charge: $0, totalPrice: totalPrice, outstandingOrder: outstandingOrder).create(on: req) }
                        .and(outstandingOrder.constructedItems.query(on: req).all())
                        .flatMap { self.insert(purchasedOrder: $0, constructedItems: $1, req: req).transform(to: $0) }
                }
            }
    }

    // MARK: - Helper Methods
    private func database(_ req: Request) -> Future<MongoKitten.Database> {
        return MongoKitten.Database
            .connect(AppConstants.MongoDB.Local.uri, on: req.eventLoop)
    }

    private func stripeClient(_ req: Request) throws -> StripeClient {
        return try req.make(StripeClient.self)
    }

    private func verifiedUser(_ userID: User.ID, req: Request) throws -> Future<User> {
        return User.find(userID, on: req).unwrap(or: Abort(.badRequest))
            .and(try verifier.verify(req))
            .guard({ $0.uid == $1 }, else: Abort(.unauthorized))
            .map { user, _ in user }
    }

    private func createCharge(for amount: Int, user: User, source: String?, req: Request) throws -> Future<StripeCharge> {
        return try self.stripeClient(req).charge.create(amount: amount, currency: .usd, customer: user.customerID, source: source)
    }

    private func makePurchasedOrder(user: User, charge: StripeCharge, totalPrice: Int, outstandingOrder: OutstandingOrder) throws -> PurchasedOrder {
        return PurchasedOrder(
            userID: try user.requireID(),
            chargeID: charge.id,
            totalPrice: totalPrice,
            purchasedDate: Date(),
            preparedForDate: outstandingOrder.preparedForDate,
            note: outstandingOrder.note)
    }

    private func makeConstructedItemDocumentData(category: Category, totalPrice: Int, items: [ConstructedItemCategorizedItems]) throws -> ConstructedItemDocumentData {
        return try ConstructedItemDocumentData(id: UUID(), totalPrice: totalPrice, category: CategoryDocumentData(id: category.requireID(), name: category.name), items: items)
    }

    private func insert(purchasedOrder: PurchasedOrder, constructedItems: [ConstructedItem], req: Request) -> Future<Void> {
        let categorizedItemsCreator = ConstructedItemCategorizedItemsCreator()
        return database(req).flatMap { database in
            try constructedItems.map {
                try $0.category.get(on: req)
                    .and($0.totalPrice(on: req))
                    .and(categorizedItemsCreator.create(for: $0, on: req))
                    .map { let ((category, totalPrice), items) = $0
                        return try self.makeConstructedItemDocumentData(category: category, totalPrice: totalPrice, items: items)
                }}.flatten(on: req).map {
                    try PurchasedOrderDocumentData(purchasedOrderID: purchasedOrder.requireID(), constructedItems: $0)
                }.map { try BSONEncoder().encode($0) }
                .flatMap { database[CollectionNames.purchasedOrders].insert($0) }
                .transform(to: ())
        }
    }
}

extension PurchasedOrderController: RouteCollection {
    func boot(router: Router) throws {
        let purchasedOrdersRouter = router.grouped("\(AppConstants.version)/purchasedOrders")
        
        // POST /purchasedOrders
        purchasedOrdersRouter.post(CreateData.self, use: create)
    }
}

private extension PurchasedOrderController {
    struct CreateData: Content {
        let userID: User.ID
        let source: String?
        let outstandingOrderID: OutstandingOrder.ID
    }
}

private extension PurchasedOrderController {
    struct PurchasedOrderDocumentData: Codable {
        let purchasedOrderID: PurchasedOrder.ID
        let constructedItems: [ConstructedItemDocumentData]
    }

    struct ConstructedItemDocumentData: Codable {
        let id: UUID
        let totalPrice: Int
        let category: CategoryDocumentData
        let items: [ConstructedItemCategorizedItems]
    }

    struct CategoryDocumentData: Codable {
        let id: Category.ID
        let name: String
    }
}
