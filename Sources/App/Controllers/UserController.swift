import Vapor
import FluentPostgreSQL
import JWT
import Crypto

final class UserController {
	let google = GoogleAPIManager()
	
	func save(_ req: Request, user: User) throws -> Future<User> {
		return try verify(req).flatMap { uid in
			guard user.uid == uid else { throw Abort(.unauthorized) }
			return user.save(on: req)
		}
	}
	
	func verify(_ req: Request) throws -> Future<User.UID> {
		guard let bearer = req.http.headers.bearerAuthorization
			else { throw Abort(.unauthorized) }
		return try google.publicKeys(req.client())
			.thenThrowing { keys -> JWTSigners in
				let signers = JWTSigners()
				try keys.forEach
				{ try signers.use(.rs256(key: .public(certificate: $1)), kid: $0) }
				return signers
			}.thenThrowing { try JWT<UserUIDPayload>(from: bearer.token, verifiedUsing: $0).payload.sub.value }
	}
}

extension UserController: RouteCollection {
	func boot(router: Router) throws {
		let usersRoute = router.grouped("\(AppConstants.version)/users")
		
		usersRoute.post(User.self, use: save)
	}
}
