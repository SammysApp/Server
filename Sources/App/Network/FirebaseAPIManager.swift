import Vapor

private struct Constants {
	struct Auth {
		static let baseURL = "https://www.googleapis.com/identitytoolkit/v3/relyingparty"
	}
}

enum FirebaseEndpoint: ClientEndpoint {
	case userData
	
	var data: ClientEndpointData {
		switch self {
		case .userData: return .init(method: .POST,
									 url: Constants.Auth.baseURL + "/getAccountInfo")
		}
	}
}

struct FirebaseAPIManager {
	let apiKey: String
	
	func userData(_ content: UserDataRequest, client: Client)
		-> Future<UserDataResponse> {
		return FirebaseEndpoint.userData.send(on: client) { req in
			try req.query.encode(["key": apiKey])
			try req.content.encode(content)
		}.flatMap { res in
			switch res.http.status {
			case .ok: return try res.content.decode(UserDataRawResponse.self).map(UserDataResponse.init)
			default: throw Abort(res.http.status)
			}
		}
	}
}

struct UserDataRequest: Content {
	let idToken: String
}

struct UserDataRawResponse: Content {
	let users: [User]
	
	struct User: Content {
		let localId: String
	}
}

struct UserDataResponse: Content {
	let uid: String?
	
	init(raw: UserDataRawResponse) {
		let user = raw.users.first
		self.uid = user?.localId
	}
}
