import Vapor
import FluentPostgreSQL

final class UserController {
	let firebase = FirebaseAPIManager(apiKey: AppSecrets.Firebase.apiKey)
	
	func users(_ req: Request, content: UserDataRequest) throws
		-> Future<UserDataResponse> {
		return try firebase.userData(content, client: req.client())
	}
}

extension UserController: RouteCollection {
	func boot(router: Router) throws {
		let usersRoute = router.grouped("\(AppConstants.version)/users")
		
		usersRoute.post(UserDataRequest.self, use: users)
	}
}
