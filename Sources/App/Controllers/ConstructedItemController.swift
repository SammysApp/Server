import Vapor
import FluentPostgreSQL

final class ConstructedItemController {
	let userController = UserController()
	
	func constructedItem(_ req: Request) throws -> Future<ConstructedItem> {
		return try req.parameters.next(ConstructedItem.self)
	}
	
	func verifiedUpdate(_ req: Request) throws -> Future<ConstructedItem> {
		return try userController.verifiedUser(req)
			.and(req.content.decode(ConstructedItem.self))
			.flatMap { user, constructedItem in
				constructedItem.userID = try user.requireID()
				return constructedItem.save(on: req)
			}
	}
}

extension ConstructedItemController: RouteCollection {
	func boot(router: Router) throws {
		let constructedItemsRoute =
			router.grouped("\(AppConstants.version)/constructedItems")
		
		constructedItemsRoute.get(ConstructedItem.parameter, use: constructedItem)
		constructedItemsRoute.put(use: verifiedUpdate)
	}
}
