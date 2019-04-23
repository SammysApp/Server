import Foundation

enum SquareCardBrand: String, Codable {
    case visa = "VISA"
    case mastercard = "MASTERCARD"
    case americanExpress = "AMERICAN_EXPRESS"
    case discover = "DISCOVER"
    case discoverDiners = "DISCOVER_DINERS"
    case jcb = "JCB"
    case chinaUnionPay = "CHINA_UNIONPAY"
}

extension SquareCardBrand {
    var name: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .americanExpress: return "Amex"
        case .discover: return "Discover"
        case .discoverDiners: return "Discover Diners"
        case .jcb: return "JCB"
        case .chinaUnionPay: return "China Union Pay"
        }
    }
}
