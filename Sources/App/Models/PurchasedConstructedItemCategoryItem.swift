import Vapor
import FluentPostgreSQL

final class PurchasedConstructedItemCategoryItem: PostgreSQLUUIDModel, ModifiablePivot {
    typealias Left = PurchasedConstructedItem
    typealias Right = CategoryItem
    
    static let leftIDKey: LeftIDKey = \.constructedItemID
    static let rightIDKey: RightIDKey = \.categoryItemID
    
    var id: PurchasedConstructedItemCategoryItem.ID?
    var constructedItemID: PurchasedConstructedItem.ID
    var categoryItemID: CategoryItem.ID
    
    var paidPrice: Int?
    
    init(_ constructedItem: PurchasedConstructedItem, _ categoryItem: CategoryItem) throws {
        self.constructedItemID = try constructedItem.requireID()
        self.categoryItemID = try categoryItem.requireID()
    }
}

extension PurchasedConstructedItemCategoryItem: Migration {}
