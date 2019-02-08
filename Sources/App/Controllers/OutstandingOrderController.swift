import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
	let verifier = UserRequestVerifier()
	
	// MARK: - GET
	func create(_ req: Request, data: CreateData)
		-> Future<OutstandingOrder> {
		return OutstandingOrder().create(on: req).flatMap { outstandingOrder in
			if let constructedItems = data.constructedItems {
				return ConstructedItem.query(on: req).filter(\.id ~~ constructedItems).all()
					.then { outstandingOrder.constructedItems.attachAll($0, on: req) }
					.transform(to: outstandingOrder)
			} else { return req.future(outstandingOrder) }
		}
	}
	
	// MARK: - PUT
	func update(_ req: Request, outstandingOrder: OutstandingOrder)
		throws -> Future<OutstandingOrder> {
		return try req.parameters.next(OutstandingOrder.self).flatMap { existing in
			outstandingOrder.id = try existing.requireID()
			if let userID = outstandingOrder.userID {
				return User.find(userID, on: req).unwrap(or: Abort(.badRequest))
					.and(try self.verifier.verify(req)).assertMatching(or: Abort(.unauthorized))
					.then { outstandingOrder.update(on: req) }
			} else { return outstandingOrder.update(on: req) }
		}
	}
}

extension OutstandingOrderController: RouteCollection {
	func boot(router: Router) throws {
		let outstandingOrdersRouter = router
			.grouped("\(AppConstants.version)/outstandingOrders")
		
		outstandingOrdersRouter.post(CreateData.self, use: create)
		
		outstandingOrdersRouter.put(OutstandingOrder.self, at: OutstandingOrder.parameter, use: update)
	}
}

extension OutstandingOrderController {
	struct CreateData: Content {
		let constructedItems: [ConstructedItem.ID]?
	}
}

private extension Future where T == (User, User.UID) {
	func assertMatching(or error: Error) -> Future<Void> {
		return thenThrowing { guard $0.0.uid == $0.1 else { throw error }; return }
	}
}
