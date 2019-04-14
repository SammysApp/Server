import Foundation

enum SquareCardBrand: String, Codable {
    case visa = "VISA"
    case mastercard = "MASTERCARD"
    case americanExpress = "AMERICAN_EXPRESS"
    case discover = "DISCOVER"
}

extension SquareCardBrand {
    var name: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .americanExpress: return "American Express"
        case .discover: return "Discover"
        }
    }
}
