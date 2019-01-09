import Vapor

/// Registers application routes.
public func routes(_ router: Router) throws {
	let stripeController = StripeController()
	try router.register(collection: stripeController)
	
	let categoryController = CategoryController()
	try router.register(collection: categoryController)
	
	let itemController = ItemController()
	try router.register(collection: itemController)
}
