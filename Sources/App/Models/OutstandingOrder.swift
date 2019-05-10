import Vapor
import FluentPostgreSQL

final class OutstandingOrder: PostgreSQLUUIDModel {
    var id: OutstandingOrder.ID?
    var userID: User.ID?
    var preparedForDate: Date?
    var note: String?
    
    init(id: OutstandingOrder.ID? = nil,
         userID: User.ID? = nil,
         preparedForDate: Date? = nil,
         note: String? = nil) {
        self.id = id
        self.userID = userID
        self.preparedForDate = preparedForDate
        self.note = note
    }
}

extension OutstandingOrder: Parameter {}
extension OutstandingOrder: Content {}
extension OutstandingOrder: Migration {}

extension OutstandingOrder {
    var constructedItems: Siblings<OutstandingOrder, ConstructedItem, OutstandingOrderConstructedItem> { return siblings() }
}

extension OutstandingOrder {
    var offers: Siblings<OutstandingOrder, Offer, OutstandingOrderOffer> { return siblings() }
}

extension OutstandingOrder {
    func pivot(attaching constructedItem: ConstructedItem, on conn: DatabaseConnectable) throws -> Future<OutstandingOrderConstructedItem?> {
        return try constructedItems.pivots(on: conn)
            .filter(\.outstandingOrderID == requireID())
            .filter(\.constructedItemID == constructedItem.requireID())
            .first()
    }
}

extension OutstandingOrder {
    func totalPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try baseTotalPrice(on: conn)
    }
    
    func totalDiscountPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try offers.query(on: conn)
            .filter(\.availability == .isAvailable).all().flatMap { availableOffers in
            let totalDiscountPrice = availableOffers
                .compactMap { $0.discountPrice }.reduce(0, +)
            let totalDiscountPercent = availableOffers
                .compactMap { $0.discountPercent }.reduce(0, +)
            let totalDiscountPercentMultiplier = totalDiscountPercent/100
            return try self.baseTotalPrice(on: conn).map { totalPrice in
                (totalPrice * totalDiscountPercentMultiplier) + totalDiscountPrice
            }
        }
    }
    
    private func totalConstructedItemsPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try constructedItems.query(on: conn)
            .alsoDecode(OutstandingOrderConstructedItem.self).all().flatMap { result in
                return try result.map { constructedItem, outstandingOrderConstructedItem in
                    return try constructedItem.totalPrice(on: conn).map { $0  * outstandingOrderConstructedItem.quantity }
                }.flatten(on: conn).map { $0.reduce(0, +) }
            }
    }
    
    private func baseTotalPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try totalConstructedItemsPrice(on: conn)
    }
}
