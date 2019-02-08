import Vapor

/// Registers application routes.
public func routes(_ router: Router) throws {
	let userController = UserController()
	try router.register(collection: userController)
	
	let categoryController = CategoryController()
	try router.register(collection: categoryController)
	
	let itemController = ItemController()
	try router.register(collection: itemController)
	
	let constructedItemController = ConstructedItemController()
	try router.register(collection: constructedItemController)
	
	let outstandingOrderController = OutstandingOrderController()
	try router.register(collection: outstandingOrderController)
	
	let stripeController = StripeController()
	try router.register(collection: stripeController)
}
