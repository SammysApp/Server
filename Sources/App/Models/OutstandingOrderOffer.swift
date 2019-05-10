import Vapor
import FluentPostgreSQL

final class OutstandingOrderOffer: PostgreSQLUUIDPivot, ModifiablePivot {
    typealias Left = OutstandingOrder
    typealias Right = Offer
    
    static let leftIDKey: LeftIDKey = \.outstandingOrderID
    static let rightIDKey: RightIDKey = \.offerID
    
    var id: OutstandingOrderOffer.ID?
    var outstandingOrderID: OutstandingOrder.ID
    var offerID: Offer.ID
    
    init(_ outstandingOrder: OutstandingOrder, _ offer: Offer) throws {
        self.outstandingOrderID = try outstandingOrder.requireID()
        self.offerID = try offer.requireID()
    }
}

extension OutstandingOrderOffer: Migration {}
