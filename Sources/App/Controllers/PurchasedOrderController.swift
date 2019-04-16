import Vapor
import Fluent
import FluentPostgreSQL

final class PurchasedOrderController {
    private func get(_ req: Request) -> Future<[PurchasedOrder]> {
        return PurchasedOrder.query(on: req).all()
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[PurchasedConstructedItem]> {
        return try req.parameters.next(PurchasedOrder.self).flatMap { purchasedOrder in
            try purchasedOrder.constructedItems.query(on: req).all()
        }
    }
    
    private func getConstructedItemItems(_ req: Request) throws -> Future<[CategoryItem]> {
        return try req.parameters.next(PurchasedOrder.self)
            .and(req.parameters.next(PurchasedConstructedItem.self))
            .flatMap { purchasedOrder, constructedItem in
                try constructedItem.categoryItems.query(on: req).all()
            }
    }
}

extension PurchasedOrderController: RouteCollection {
    func boot(router: Router) throws {
        let purchasedOrdersRouter = router.grouped("\(AppConstants.version)/purchasedOrders")
        
        // GET /purchasedOrders
        purchasedOrdersRouter.get(use: get)
        // GET /purchasedOrders/:purchasedOrder/constructedItems
        purchasedOrdersRouter.get(PurchasedOrder.parameter, "constructedItems", use: getConstructedItems)
        // GET /purchasedOrders/:purchasedOrder/constructedItems/:constructedItem/items
        purchasedOrdersRouter.get(PurchasedOrder.parameter, "constructedItems", PurchasedConstructedItem.parameter, "items", use: getConstructedItemItems)
    }
}
