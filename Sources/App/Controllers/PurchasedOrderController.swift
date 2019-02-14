import Vapor
import FluentPostgreSQL
import MongoKitten
import Stripe

final class PurchasedOrderController {
	private let verifier = UserRequestVerifier()
	
	// MARK: - POST
	private func create(_ req: Request, data: CreateData)
		throws -> Future<PurchasedOrder> {
		return try verifiedUser(data.userID, req: req)
			.and(OutstandingOrder.find(data.outstandingOrderID, on: req)
				.unwrap(or: Abort(.badRequest)))
			.map(self.purchasedOrder).flatMap { $0.create(on: req) }
	}
	
	// MARK: - Helper Methods
	private func database(_ req: Request) -> Future<MongoKitten.Database> {
		return MongoKitten.Database
			.connect(AppConstants.MongoDB.Local.uri, on: req.eventLoop)
	}
	
	func stripeClient(_ req: Request) throws -> StripeClient {
		return try req.make(StripeClient.self)
	}
	
	private func purchasedOrder(user: User, outstandingOrder: OutstandingOrder)
		throws -> PurchasedOrder {
		return try PurchasedOrder(
			userID: user.requireID(),
			chargeID: "",
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
		let constructedItems: [ConstructedItemData]
		
		struct ConstructedItemData: Codable {
			let id = UUID()
			let items: [ConstructedItemCategorizedItems]
		}
	}
}
