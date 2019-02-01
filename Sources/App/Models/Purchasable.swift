import Foundation

protocol Purchasable {
	var price: Double? { get set }
}

extension Purchasable {
	var decimalPrice: Decimal? {
		guard let price = price else { return nil }
		return Decimal(price)
	}
}

extension Array where Element == Purchasable {
	var totalPrice: Decimal { return reduce(0) { $0 + ($1.decimalPrice ?? 0) } }
}
