import Foundation

struct SquareMoney: Codable {
    let amount: Int
    let currency: Currency
}

enum Currency: String, Codable {
    case usd = "USD"
}
