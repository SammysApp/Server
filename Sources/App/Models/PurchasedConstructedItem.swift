import Vapor
import FluentPostgreSQL

final class PurchasedConstructedItem: PostgreSQLUUIDModel {
    var id: PurchasedConstructedItem.ID?
    var orderID: PurchasedOrder.ID
    var constructedItemID: ConstructedItem.ID
    var totalPrice: Int
    
    init(id: PurchasedConstructedItem.ID? = nil,
         orderID: PurchasedOrder.ID,
         constructedItemID: ConstructedItem.ID,
         totalPrice: Int) {
        self.id = id
        self.orderID = orderID
        self.constructedItemID = constructedItemID
        self.totalPrice = totalPrice
    }
}

extension PurchasedConstructedItem: Parameter {}
extension PurchasedConstructedItem: Content {}
extension PurchasedConstructedItem: Migration {}

extension PurchasedConstructedItem {
    var order: Parent<PurchasedConstructedItem, PurchasedOrder>? {
        return parent(\.orderID)
    }
}

extension PurchasedConstructedItem {
    var constructedItem: Parent<PurchasedConstructedItem, ConstructedItem>? {
        return parent(\.constructedItemID)
    }
}

extension PurchasedConstructedItem {
    var categoryItems: Siblings<PurchasedConstructedItem, CategoryItem, PurchasedConstructedItemCategoryItem> { return siblings() }
}
