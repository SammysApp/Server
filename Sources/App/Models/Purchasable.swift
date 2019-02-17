import Foundation

protocol Purchasable {
    var price: Int? { get set }
}

extension Array where Element == Purchasable {
    var totalPrice: Int { return reduce(0) { $0 + ($1.price ?? 0) } }
}
