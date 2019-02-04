import Vapor

enum GoogleEndpoint: ClientEndpoint {
	case publicKeys
	
	var data: ClientEndpointData {
		switch self {
		case .publicKeys:
			return .init(method: .GET, url: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
		}
	}
}

struct GoogleAPIManager {
	func publicKeys(_ client: Client) -> Future<[String : String]> {
		return GoogleEndpoint.publicKeys.send(on: client)
			.flatMap { try $0.content.decode([String : String].self) }
	}
}
