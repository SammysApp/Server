import Vapor

extension Future where T == User {
	func assert(has uid: User.UID, or error: Error) -> Future<User> {
		return thenThrowing { guard $0.uid == uid else { throw error }; return $0 }
	}
}

extension Future where T == (User, User.UID) {
	func assertMatching(or error: Error) -> Future<Void> {
		return thenThrowing { guard $0.uid == $1 else { throw error }; return }
	}
	
	func assertMatching(or error: Error) -> Future<User> {
		return thenThrowing { guard $0.uid == $1 else { throw error }; return $0 }
	}
}
