import Vapor
import FluentPostgreSQL
import JWT
import Crypto

final class UserController {
	let verifier = UserRequestVerifier()
	
	// MARK: - GET
	private func getConstructedItems(_ req: Request)
		throws -> Future<[ConstructedItem]> {
		return try verifier.verify(req)
			.flatMap { try req.parameters.next(User.self)
				.assert(has: $0, or: Abort(.unauthorized)) }
			.flatMap { try self.constructedItems(for: $0, req: req) }
	}
	
	private func getOutstandingOrders(_ req: Request)
		throws -> Future<[OutstandingOrder]> {
		return try verifier.verify(req)
			.flatMap { try req.parameters.next(User.self)
				.assert(has: $0, or: Abort(.unauthorized)) }
			.flatMap { try self.outstandingOrders(for: $0, req: req) }
	}
	
	// MARK: - POST
	private func create(_ req: Request) throws -> Future<User> {
		return try verifier.verify(req).flatMap { User(uid: $0).create(on: req) }
	}
	
	// MARK: - Helper Methods
	private func constructedItems(for user: User, req: Request)
		throws -> Future<[ConstructedItem]> {
		var databaseQuery = try user.constructedItems.query(on: req)
		if let requestQuery = try? req.query.decode(ConstructedItemsQuery.self) {
			if let isFavorite = requestQuery.isFavorite {
				databaseQuery = databaseQuery.filter(\.isFavorite == isFavorite)
			}
		}
		return databaseQuery.all()
	}
	
	private func outstandingOrders(for user: User, req: Request)
		throws -> Future<[OutstandingOrder]> {
		return try user.outstandingOrders.query(on: req).all()
	}
}

extension UserController: RouteCollection {
	func boot(router: Router) throws {
		let usersRouter = router.grouped("\(AppConstants.version)/users")
		
		usersRouter.get(User.parameter, "constructedItems", use: getConstructedItems)
		usersRouter.get(User.parameter, "outstandingOrders", use: getOutstandingOrders)
		
		usersRouter.post(use: create)
	}
}

private extension UserController {
	struct ConstructedItemsQuery: Codable {
		let isFavorite: Bool?
	}
}

private extension Future where T == User {
	func assert(has uid: User.UID, or error: Error) -> Future<User> {
		return thenThrowing { guard $0.uid == uid else { throw error }; return $0 }
	}
}
