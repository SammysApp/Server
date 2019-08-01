import Vapor

/// Registers application routes.
public func routes(_ router: Router) throws {
    let storeHoursController = StoreHoursController()
    try router.register(collection: storeHoursController)
    
    let offerController = OfferController()
    try router.register(collection: offerController)
    
    let userController = UserController()
    try router.register(collection: userController)
    
    let categoryController = CategoryController()
    try router.register(collection: categoryController)
    
    let constructedItemController = ConstructedItemController()
    try router.register(collection: constructedItemController)
    
    let outstandingOrderController = OutstandingOrderController()
    try router.register(collection: outstandingOrderController)
    
    let purchasedOrderController = PurchasedOrderController()
    try router.register(collection: purchasedOrderController)
}
