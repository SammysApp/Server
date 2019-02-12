import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
	private let verifier = UserRequestVerifier()
	
	// MARK: - GET
	private func getOne(_ req: Request) throws -> Future<OutstandingOrder> {
		return try req.parameters.next(OutstandingOrder.self)
	}
	
	// MARK: - POST
	private func create(_ req: Request, data: CreateData)
		-> Future<OutstandingOrder> {
			return OutstandingOrder().create(on: req).flatMap { outstandingOrder in
				if let constructedItems = data.constructedItemIDs {
					return ConstructedItem.query(on: req).filter(\.id ~~ constructedItems).all()
						.then { outstandingOrder.constructedItems.attachAll($0, on: req) }
						.transform(to: outstandingOrder)
				} else { return req.future(outstandingOrder) }
			}
	}
	
	private func attachConstructedItems(_ req: Request, data: AttachConstructedItemsData)
		throws -> Future<OutstandingOrder> {
		return try req.parameters.next(OutstandingOrder.self)
			.and(ConstructedItem.query(on: req).filter(\.id ~~ data.ids).all())
			.then { $0.constructedItems.attachAll($1, on: req).transform(to: $0) }
	}
	
	// MARK: - PUT
	private func update(_ req: Request, outstandingOrder: OutstandingOrder)
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
		
		// GET /outstandingOrders/:outstandingOrder
		outstandingOrdersRouter.get(OutstandingOrder.parameter, use: getOne)
		
		// POST /outstandingOrders
		outstandingOrdersRouter.post(CreateData.self, use: create)
		// POST /outstandingOrders/:outstandingOrder/constructedItems
		outstandingOrdersRouter.post(AttachConstructedItemsData.self, at: OutstandingOrder.parameter, "constructedItems", use: attachConstructedItems)
		
		// PUT /outstandingOrders/:outstandingOrder
		outstandingOrdersRouter.put(OutstandingOrder.self, at: OutstandingOrder.parameter, use: update)
	}
}

private extension OutstandingOrderController {
	struct CreateData: Content {
		let constructedItemIDs: [ConstructedItem.ID]?
	}
	
	struct AttachConstructedItemsData: Content {
		let ids: [ConstructedItem.ID]
	}
}
