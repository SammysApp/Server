import Vapor

final class ItemController: RouteCollection {
	func boot(router: Router) throws {
		let itemsRoute = router.grouped("\(AppConstants.version)/items")
		
		itemsRoute.get(use: allItems)
	}
	
	func allItems(_ req: Request) -> Future<[Item]> {
		return Item.query(on: req).all()
	}
}
