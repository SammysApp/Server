import Vapor

struct GoogleAPIManager {
    enum PublicKeysEndpoint: HTTPEndpoint {
        case getPublicKeys
        
        var baseURLString: String { return "https://www.googleapis.com" }
        
        var endpoint: (HTTPMethod, URLPath) {
            switch self {
            case .getPublicKeys:
                return (.GET, "/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
            }
        }
    }
    
    func publicKeys(_ client: Client) -> Future<[String : String]> {
        return client.send(PublicKeysEndpoint.getPublicKeys)
            .flatMap { try $0.content.decode([String : String].self) }
    }
}
