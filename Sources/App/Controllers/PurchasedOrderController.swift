import Vapor
import FluentPostgreSQL
import MongoKitten
import Stripe

final class PurchasedOrderController {
	private let verifier = UserRequestVerifier()
	
	enum CollectionNames: String, CollectionName {
		case purchasedOrders
	}
	
	// MARK: - POST
	private func create(_ req: Request, data: CreateData)
		throws -> Future<PurchasedOrder> {
		return try verifiedUser(data.userID, req: req)
			.and(OutstandingOrder.find(data.outstandingOrderID, on: req)
				.unwrap(or: Abort(.badRequest)))
			.guard({ $1.userID == $0.id }, else: Abort(.unauthorized))
			.flatMap { try self.createCharge(for: $1, user: $0, source: data.source, req: req).and(result: ($0, $1)) }
			.flatMap { try self.purchasedOrder(userID: $1.0.requireID(), chargeID: $0.id, outstandingOrder: $1.1).create(on: req)
				.and($1.1.constructedItems.query(on: req).all()) }
			.flatMap { self.insert($0, constructedItems: $1, req: req).transform(to: $0) }
	}
	
	// MARK: - Helper Methods
	private func database(_ req: Request) -> Future<MongoKitten.Database> {
		return MongoKitten.Database
			.connect(AppConstants.MongoDB.Local.uri, on: req.eventLoop)
	}
	
	private func stripeClient(_ req: Request) throws -> StripeClient {
		return try req.make(StripeClient.self)
	}
	
	private func insert(_ purchasedOrder: PurchasedOrder, constructedItems: [ConstructedItem], req: Request) -> Future<Void> {
		let categorizedItemsCreator = ConstructedItemCategorizedItemsCreator()
		return database(req).flatMap { database in
			try constructedItems.map { try categorizedItemsCreator.create(for: $0, on: req) }.flatten(on: req)
				.map { $0.map { (UUID().uuidString, $0) } }
				.map { Dictionary(uniqueKeysWithValues: $0) }
				.map { try PurchasedOrderDocumentData(purchasedOrderID: purchasedOrder.requireID(), constructedItems: $0) }
				.map { try BSONEncoder().encode($0) }
				.flatMap { database[CollectionNames.purchasedOrders].insert($0) }
				.transform(to: ())
		}
	}
	
	private func createCharge(for outstandingOrder: OutstandingOrder, user: User, source: String?, req: Request) throws -> Future<StripeCharge> {
		return try outstandingOrder.totalPrice(on: req).flatMap {
			try self.stripeClient(req).charge.create(amount: $0, currency: .usd, customer: user.customerID, source: source)
		}
	}
	
	private func purchasedOrder(userID: User.ID, chargeID: String, outstandingOrder: OutstandingOrder) -> PurchasedOrder {
		return PurchasedOrder(
			userID: userID,
			chargeID: chargeID,
			purchasedDate: Date(),
			preparedForDate: outstandingOrder.preparedForDate,
			note: outstandingOrder.note)
	}
	
	private func verifiedUser(_ userID: User.ID, req: Request) throws -> Future<User> {
		return User.find(userID, on: req).unwrap(or: Abort(.badRequest))
			.and(try verifier.verify(req)).assertMatching(or: Abort(.unauthorized))
	}
}

extension PurchasedOrderController: RouteCollection {
	func boot(router: Router) throws {
		let purchasedOrdersRouter = router.grouped("\(AppConstants.version)/purchasedOrders")
		
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
		let constructedItems: [String : [ConstructedItemCategorizedItems]]
	}
}
