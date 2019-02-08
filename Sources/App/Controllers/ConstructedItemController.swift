import Vapor
import FluentPostgreSQL

final class ConstructedItemController {
	private let userController = UserController()
	
	func constructedItem(_ req: Request) throws -> Future<ConstructedItem> {
		return try req.parameters.next(ConstructedItem.self)
	}
}

extension ConstructedItemController: RouteCollection {
	func boot(router: Router) throws {
		let constructedItemsRoute =
			router.grouped("\(AppConstants.version)/constructedItems")
		
		constructedItemsRoute.get(ConstructedItem.parameter, use: constructedItem)
	}
}
