import Vapor
import JWT

struct UserUIDPayload: JWTPayload {
	let exp: ExpirationClaim
	let iat: IssuedAtClaim
	let aud: AudienceClaim
	let iss: IssuerClaim
	let sub: SubjectClaim
	let auth_time: AuthTimeClaim
	
	func verify(using signer: JWTSigner) throws {
		try exp.verifyNotExpired()
		try iat.verify()
		try aud.verify(isEqualTo: "sammys-73b4d")
		try iss.verify(isEqualTo: "https://securetoken.google.com/sammys-73b4d")
		try auth_time.verify()
	}
}

struct AuthTimeClaim: JWTUnixEpochClaim {
	var value: Date
}

extension JWTUnixEpochClaim {
	func verify(isBefore date: Date = .init(), or error: JWTError? = nil) throws {
		switch value.compare(date) {
		case .orderedAscending: break
		case .orderedDescending, .orderedSame: throw error ?? verifyError
		}
	}
}

extension JWTClaim where Value == String {
	func verify(isEqualTo string: String, or error: Error? = nil) throws {
		guard value == string else { throw error ?? verifyError }
	}
}

extension JWTClaim {
	var verifyError: JWTError {
		switch Self.self {
		case is IssuedAtClaim.Type:
			return JWTError(identifier: "iat", reason: "Issued at claim failed")
		case is AudienceClaim.Type:
			return JWTError(identifier: "aud", reason: "Audience claim failed")
		case is IssuerClaim.Type:
			return JWTError(identifier: "iss", reason: "Issuer claim failed")
		default: return JWTError(identifier: "error", reason: "Claim failed")
		}
	}
}
