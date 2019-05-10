import Vapor
import Fluent
import FluentPostgreSQL

final class PurchasedOrderController {
    let calendar = Calendar(identifier: .gregorian)
    
    let queryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.queryDateFormat
        return formatter
    }()
    
    private struct Constants {
        static let queryDateFormat = "M-d-yyyy"
    }
    
    // MARK: - GET
    private func get(_ req: Request) throws -> Future<[PurchasedOrderResponseData]> {
        guard var startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())
            else { throw Abort(.internalServerError) }
        if let reqQuery = try? req.query.decode(GetPurchasedOrdersRequestQueryData.self) {
            if let queryDateString = reqQuery.date,
                let queryStartDate = queryDateFormatter.date(from: queryDateString) {
                startDate = queryStartDate
            }
        }
        guard let endDateNotIncluding = calendar.date(byAdding: .day, value: 1, to: startDate)
            else { throw Abort(.internalServerError) }
        return PurchasedOrder.query(on: req)
            .filter(\.purchasedDate >= startDate)
            .filter(\.purchasedDate < endDateNotIncluding)
            .join(\User.id, to: \PurchasedOrder.userID).alsoDecode(User.self).all()
            .map { try $0.map(self.makePurchasedOrderResponseData) }
    }
    
    private func getOne(_ req: Request) throws -> Future<PurchasedOrderResponseData> {
        return try req.parameters.next(PurchasedOrder.self)
            .flatMap { try self.makePurchasedOrderResponseData(purchasedOrder: $0, conn: req) }
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[PurchasedConstructedItemResponseData]> {
        return try req.parameters.next(PurchasedOrder.self)
            .flatMap {  try $0.constructedItems.query(on: req).all() }
            .flatMap { purchasedConstructedItems in
                purchasedConstructedItems.map { self.makePurchasedConstructedItemResponseData(purchasedConstructedItem: $0, conn: req) }.flatten(on: req)
            }
    }
    
    private func getConstructedItemItems(_ req: Request) throws -> Future<[CategorizedItemsResponseData]> {
        return try req.parameters.next(PurchasedOrder.self)
            .and(req.parameters.next(PurchasedConstructedItem.self))
            .flatMap { purchasedOrder, purchasedConstructedItem in
                self.makeCategorizedItemsResponseData(purchasedConstructedItem: purchasedConstructedItem, conn: req)
            }
    }
    
    // MARK: - PATCH
    private func partiallyUpdate(_ req: Request, data: PartialUpdateRequestData) throws -> Future<PurchasedOrderResponseData> {
        return try req.parameters.next(PurchasedOrder.self).flatMap { purchasedOrder -> Future<PurchasedOrder> in
            if let progress = data.progress {
                purchasedOrder.progress = progress
            }
            return purchasedOrder.update(on: req)
        }.flatMap { try self.makePurchasedOrderResponseData(purchasedOrder: $0, conn: req) }
    }
    
    // MARK: - Helper Methods
    private func makePurchasedOrderResponseData(purchasedOrder: PurchasedOrder, conn: DatabaseConnectable) throws -> Future<PurchasedOrderResponseData> {
        return purchasedOrder.user.get(on: conn)
            .map { try self.makePurchasedOrderResponseData(purchasedOrder: purchasedOrder, user: $0) }
    }
    
    private func makePurchasedOrderResponseData(purchasedOrder: PurchasedOrder, user: User) throws -> PurchasedOrderResponseData {
        return try PurchasedOrderResponseData(
            id: purchasedOrder.requireID(),
            number: purchasedOrder.number,
            purchasedDate: purchasedOrder.purchasedDate,
            preparedForDate: purchasedOrder.preparedForDate,
            note: purchasedOrder.note,
            progress: purchasedOrder.progress,
            user: user
        )
    }
    
    private func makePurchasedConstructedItemResponseData(purchasedConstructedItem: PurchasedConstructedItem, conn: DatabaseConnectable) -> Future<PurchasedConstructedItemResponseData> {
        return purchasedConstructedItem.constructedItem.query(on: conn)
            .first().unwrap(or: Abort(.internalServerError))
            .flatMap { $0.category.query(on: conn)
                .first().unwrap(or: Abort(.internalServerError)) }.map { category in
                try PurchasedConstructedItemResponseData(
                    id: purchasedConstructedItem.requireID(),
                    name: category.name,
                    quantity: purchasedConstructedItem.quantity
                )
            }
    }
    
    private func makeCategoryResponseData(category: Category) throws -> CategoryResponseData {
        return try CategoryResponseData(
            id: category.requireID(),
            name: category.name
        )
    }
    
    private func makeItemResponseData(categoryItem: CategoryItem, item: Item) throws -> ItemResponseData {
        return try ItemResponseData(
            id: item.requireID(),
            name: item.name
        )
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
        // GET /purchasedOrders/:purchasedOrder
        purchasedOrdersRouter.get(PurchasedOrder.parameter, use: getOne)
        // GET /purchasedOrders/:purchasedOrder/constructedItems
        purchasedOrdersRouter.get(PurchasedOrder.parameter, "constructedItems", use: getConstructedItems)
        // GET /purchasedOrders/:purchasedOrder/constructedItems/:constructedItem/items
        purchasedOrdersRouter.get(PurchasedOrder.parameter, "constructedItems", PurchasedConstructedItem.parameter, "items", use: getConstructedItemItems)
        
        // PATCH /purchasedOrders/:purchasedOrder
        purchasedOrdersRouter.patch(PartialUpdateRequestData.self, at: PurchasedOrder.parameter, use: partiallyUpdate)
    }
}

private extension PurchasedOrderController {
    struct GetPurchasedOrdersRequestQueryData: Content {
        /// Date in `M-d-yyyy` format.
        let date: String?
    }
}

private extension PurchasedOrderController {
    struct PartialUpdateRequestData: Content {
        let progress: OrderProgress?
    }
}

private extension PurchasedOrderController {
    struct PurchasedOrderResponseData: Content {
        let id: PurchasedOrder.ID
        let number: Int?
        let purchasedDate: Date
        let preparedForDate: Date?
        let note: String?
        let progress: OrderProgress
        let user: User
    }
    
    struct PurchasedConstructedItemResponseData: Content {
        let id: PurchasedConstructedItem.ID
        let name: String
        let quantity: Int
    }
    
    struct CategoryResponseData: Content {
        let id: Category.ID
        let name: String
    }
    
    struct ItemResponseData: Content {
        let id: Item.ID
        let name: String
    }
    
    struct CategorizedItemsResponseData: Content {
        let category: CategoryResponseData
        let items: [ItemResponseData]
    }
}
