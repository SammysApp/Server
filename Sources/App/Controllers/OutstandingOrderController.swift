import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
	func save(_ req: Request, outstandingOrder: OutstandingOrder) -> Future<OutstandingOrder> {
		return outstandingOrder.save(on: req)
	}
	
	func create(_ req: Request, data: CreateData)
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
		
		outstandingOrdersRoute.post(CreateData.self, use: create)
	}
}

extension OutstandingOrderController {
	struct CreateData: Content {
		let constructedItems: [ConstructedItem.ID]?
	}
}
