import Vapor
import FluentPostgreSQL

final class PurchasedOrder: PostgreSQLUUIDModel {
    var id: PurchasedOrder.ID?
    var number: Int?
    var userID: User.ID
    var transactionID: SquareTransaction.ID
    var totalPrice: Int
    var purchasedDate: Date
    var preparedForDate: Date?
    var note: String?
    var progress: OrderProgress
    
    init(id: PurchasedOrder.ID? = nil,
         number: Int? = nil,
         userID: User.ID,
         transactionID: SquareTransaction.ID,
         totalPrice: Int,
         purchasedDate: Date,
         preparedForDate: Date? = nil,
         note: String? = nil,
         progress: OrderProgress = .isPending) {
        self.id = id
        self.number = number
        self.userID = userID
        self.transactionID = transactionID
        self.totalPrice = totalPrice
        self.purchasedDate = purchasedDate
        self.preparedForDate = preparedForDate
        self.note = note
        self.progress = progress
    }
}

extension PurchasedOrder: Parameter {}
extension PurchasedOrder: Content {}

extension PurchasedOrder: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.create(PurchasedOrder.self, on: conn) { creator in
            creator.field(for: \.id, isIdentifier: true)
            creator.field(for: \.number, type: .serial)
            creator.field(for: \.userID)
            creator.field(for: \.transactionID)
            creator.field(for: \.totalPrice)
            creator.field(for: \.purchasedDate)
            creator.field(for: \.preparedForDate)
            creator.field(for: \.note)
            creator.field(for: \.progress)
        }
    }
}
