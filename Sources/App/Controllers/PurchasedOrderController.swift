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
    
    private func getConstructedItemItems(_ req: Request) throws -> Future<[CategorizedItemsResponseData]> {
        return try req.parameters.next(PurchasedOrder.self)
            .and(req.parameters.next(PurchasedConstructedItem.self))
            .flatMap { purchasedOrder, purchasedConstructedItem in
                self.makeCategorizedItemsResponseData(purchasedConstructedItem: purchasedConstructedItem, conn: req)
            }
    }
    
    // MARK: - Helper Methods
    private func makeCategoryResponseData(category: Category) throws -> CategoryResponseData {
        return try CategoryResponseData(id: category.requireID())
    }
    
    private func makeItemResponseData(categoryItem: CategoryItem, item: Item) throws -> ItemResponseData {
        return try ItemResponseData(id: item.requireID())
    }
    
    private func makeCategorizedItemsResponseData(purchasedConstructedItem: PurchasedConstructedItem, conn: DatabaseConnectable) -> Future<[CategorizedItemsResponseData]> {
        var categorizedItems = [CategorizedItemsResponseData]()
        return purchasedConstructedItem.constructedItem.get(on: conn)
            .flatMap { $0.category.get(on: conn) }
            .flatMap { try $0.subcategories.query(on: conn).all() }.flatMap { categories in
                try categories.map { category in
                    try purchasedConstructedItem.categoryItems.query(on: conn)
                        .filter(\.categoryID == category.requireID())
                        .join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self)
                        .all().map { try $0.map(self.makeItemResponseData) }.map { items in
                            guard !items.isEmpty else { return }
                            try categorizedItems.append(.init(category: self.makeCategoryResponseData(category: category), items: items))
                        }
                }.flatten(on: conn)
            }.transform(to: categorizedItems)
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

private extension PurchasedOrderController {
    struct CategoryResponseData: Content {
        let id: Category.ID
    }
    
    struct ItemResponseData: Content {
        let id: Item.ID
    }
    
    struct CategorizedItemsResponseData: Content {
        let category: CategoryResponseData
        let items: [ItemResponseData]
    }
}
