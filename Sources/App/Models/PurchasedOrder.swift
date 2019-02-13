import Vapor
import FluentPostgreSQL

final class PurchasedOrder: PostgreSQLUUIDModel {
	var id: PurchasedOrder.ID?
	var number: Int
	var userID: User.ID
	var purchasedDate: Date
	var preparedDate: Date?
	var note: String?
	var progress: OrderProgress = .isPending
}

extension PurchasedOrder: Parameter {}
extension PurchasedOrder: Content {}
extension PurchasedOrder: Migration {}
