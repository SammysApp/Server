import Vapor

enum HTTPHeaderValue {
    case bearerAuthentication(String)
    case json
    
    var rawValue: String {
        switch self {
        case .bearerAuthentication(let token):
            return "Bearer \(token)"
        case .json:
            return "application/json"
        }
    }
}
