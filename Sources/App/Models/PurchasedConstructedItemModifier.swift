import Vapor
import FluentPostgreSQL

final class PurchasedConstructedItemModifier: PostgreSQLUUIDModel, ModifiablePivot {
    typealias Left = PurchasedConstructedItem
    typealias Right = Modifier
    
    static let leftIDKey: LeftIDKey = \.constructedItemID
    static let rightIDKey: RightIDKey = \.modifierID
    
    var id: PurchasedConstructedItemModifier.ID?
    var constructedItemID: PurchasedConstructedItem.ID
    var modifierID: Modifier.ID
    
    var paidPrice: Int?
    
    init(_ constructedItem: PurchasedConstructedItem, _ modifier: Modifier) throws {
        self.constructedItemID = try constructedItem.requireID()
        self.modifierID = try modifier.requireID()
    }
}

extension PurchasedConstructedItemModifier: Migration {}
