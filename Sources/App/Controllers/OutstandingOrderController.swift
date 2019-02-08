import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
	private let userController = UserController()
	
	func verifiedOutstandingOrders(_ req: Request) throws -> Future<[OutstandingOrder]> {
		return try userController.verifiedUser(req)
			.flatMap { try $0.outstandingOrders.query(on: req).all() }
	}
	
	func save(_ req: Request, outstandingOrder: OutstandingOrder) -> Future<OutstandingOrder> {
		return outstandingOrder.save(on: req)
	}
	
	func createOutstandingOrder(_ req: Request, data: CreateOutstandingOrderRequestData)
		-> Future<OutstandingOrder> {
		return OutstandingOrder().save(on: req).flatMap { outstandingOrder in
			if let constructedItems = data.constructedItems {
				return ConstructedItem.query(on: req).filter(\.id ~~ constructedItems).all()
					.then { outstandingOrder.constructedItems.attachAll($0, on: req) }
					.transform(to: outstandingOrder)
			} else { return req.future(outstandingOrder) }
		}
	}
}

extension OutstandingOrderController: RouteCollection {
	func boot(router: Router) throws {
		let outstandingOrdersRoute = router.grouped("\(AppConstants.version)/outstandingOrders")
		
		outstandingOrdersRoute.get(use: verifiedOutstandingOrders)
		outstandingOrdersRoute.post(CreateOutstandingOrderRequestData.self, use: createOutstandingOrder)
	}
}

struct CreateOutstandingOrderRequestData: Content {
	let constructedItems: [ConstructedItem.ID]?
}
