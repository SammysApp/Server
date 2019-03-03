import Vapor

enum GoogleEndpoint: Endpoint {
    case getPublicKeys
    
    var endpoint: (HTTPMethod, URLRepresentable) {
        switch self {
        case .getPublicKeys:
            return (.GET, "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
        }
    }
}

struct GoogleAPIManager {
    func publicKeys(_ client: Client) -> Future<[String : String]> {
        return client.send(GoogleEndpoint.getPublicKeys)
            .flatMap { try $0.content.decode([String : String].self) }
    }
}
