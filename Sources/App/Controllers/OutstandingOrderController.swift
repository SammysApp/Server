import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
	private let verifier = UserRequestVerifier()
	
	// MARK: - GET
	private func getOne(_ req: Request) throws -> Future<OutstandingOrderData> {
		return try req.parameters.next(OutstandingOrder.self)
			.flatMap { try self.verified($0, req: req) }
			.map { try OutstandingOrderData($0) }
	}
	
	// MARK: - POST
	private func create(_ req: Request, data: CreateData)
		throws -> Future<OutstandingOrderData> {
		return try verified(data, req: req).then { data in
			OutstandingOrder(userID: data.userID).create(on: req).flatMap { outstandingOrder in
				if let constructedItems = data.constructedItemIDs {
					return ConstructedItem.query(on: req)
						.filter(\.id ~~ constructedItems).all()
						.then { outstandingOrder.constructedItems.attachAll($0, on: req) }
						.transform(to: outstandingOrder)
				} else { return req.future(outstandingOrder) }
			}
		}.map { try OutstandingOrderData($0) }
	}
	
	private func attachConstructedItems(_ req: Request, data: AttachConstructedItemsData)
		throws -> Future<OutstandingOrderData> {
		return try req.parameters.next(OutstandingOrder.self)
			.flatMap { try self.verified($0, req: req) }
			.and(ConstructedItem.query(on: req).filter(\.id ~~ data.ids).all())
			.then { $0.constructedItems.attachAll($1, on: req).transform(to: $0) }
			.map { try OutstandingOrderData($0) }
	}
	
	// MARK: - PUT
	private func update(_ req: Request, outstandingOrder: OutstandingOrder)
		throws -> Future<OutstandingOrderData> {
		return try req.parameters.next(OutstandingOrder.self).flatMap { existing in
			outstandingOrder.id = try existing.requireID()
			if let userID = outstandingOrder.userID {
				return try self.verify(userID, req: req)
					.then { outstandingOrder.update(on: req) }
			} else { return outstandingOrder.update(on: req) }
		}.map { try OutstandingOrderData($0) }
	}
	
	// MARK: - Helper Methods
	private func verified(_ outstandingOrder: OutstandingOrder, req: Request)
		throws -> Future<OutstandingOrder> {
			guard let userID = outstandingOrder.userID
				else { return req.future(outstandingOrder) }
			return try verify(userID, req: req).transform(to: outstandingOrder)
	}
	
	private func verified(_ data: CreateData, req: Request) throws -> Future<CreateData> {
		guard let userID = data.userID else { return req.future(data) }
		return try verify(userID, req: req).transform(to: data)
	}
	
	private func verify(_ userID: User.ID, req: Request) throws -> Future<Void> {
		return User.find(userID, on: req).unwrap(or: Abort(.badRequest))
			.and(try verifier.verify(req)).assertMatching(or: Abort(.unauthorized))
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
		let userID: User.ID?
		let constructedItemIDs: [ConstructedItem.ID]?
	}
	
	struct AttachConstructedItemsData: Content {
		let ids: [ConstructedItem.ID]
	}
}

private extension OutstandingOrderController {
	struct OutstandingOrderData: Content {
		let id: OutstandingOrder.ID
		
		init(_ outstandingOrder: OutstandingOrder) throws {
			self.id = try outstandingOrder.requireID()
		}
	}
}
