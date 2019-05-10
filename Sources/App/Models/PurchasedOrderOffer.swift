import Vapor
import FluentPostgreSQL

final class PurchasedOrderOffer: PostgreSQLUUIDPivot, ModifiablePivot {
    typealias Left = PurchasedOrder
    typealias Right = Offer
    
    static let leftIDKey: LeftIDKey = \.purchasedOrderID
    static let rightIDKey: RightIDKey = \.offerID
    
    var id: PurchasedOrderOffer.ID?
    var purchasedOrderID: PurchasedOrder.ID
    var offerID: Offer.ID
    
    var name: String?
    var recievedDiscountPrice: Int?
    var recievedDiscountPercent: Int?
    
    init(_ purchasedOrder: PurchasedOrder, _ offer: Offer) throws {
        self.purchasedOrderID = try purchasedOrder.requireID()
        self.offerID = try offer.requireID()
    }
}

extension PurchasedOrderOffer: Migration {}
