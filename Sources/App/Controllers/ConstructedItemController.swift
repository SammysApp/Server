import Vapor
import FluentPostgreSQL

final class ConstructedItemController {
	// MARK: - GET
	func getOne(_ req: Request) throws -> Future<ConstructedItem> {
		return try req.parameters.next(ConstructedItem.self)
	}
}

extension ConstructedItemController: RouteCollection {
	func boot(router: Router) throws {
		let constructedItemsRouter =
			router.grouped("\(AppConstants.version)/constructedItems")
		
		constructedItemsRouter.get(ConstructedItem.parameter, use: getOne)
	}
}
