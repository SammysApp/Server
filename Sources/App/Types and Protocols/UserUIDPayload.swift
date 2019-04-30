import Vapor
import JWT

struct UserUIDPayload: JWTPayload {
    private let exp: ExpirationClaim
    private let iat: IssuedAtClaim
    private let aud: AudienceClaim
    private let iss: IssuerClaim
    private let sub: SubjectClaim
    private let auth_time: AuthTimeClaim
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
        try iat.verify()
        try aud.verify(isEqualTo: AppConstants.Firebase.projectName)
        try iss.verify(isEqualTo: "https://securetoken.google.com/\(AppConstants.Firebase.projectName)")
        try auth_time.verify()
        guard !sub.value.isEmpty else { throw sub.verifyError }
    }
}

extension UserUIDPayload {
    var uid: User.UID { return sub.value }
}

private struct AuthTimeClaim: JWTUnixEpochClaim {
    var value: Date
}

private extension JWTUnixEpochClaim {
    func verify(isBefore date: Date = .init(), or error: JWTError? = nil) throws {
        switch self.value.compare(date) {
        case .orderedAscending: break
        case .orderedDescending, .orderedSame: throw error ?? self.verifyError
        }
    }
}

private extension JWTClaim where Value == String {
    func verify(isEqualTo string: String, or error: Error? = nil) throws {
        guard self.value == string else { throw error ?? self.verifyError }
    }
}

private extension JWTClaim {
    var verifyError: JWTError {
        switch Self.self {
        case is IssuedAtClaim.Type:
            return JWTError(identifier: "iat", reason: "Issued at claim failed")
        case is AudienceClaim.Type:
            return JWTError(identifier: "aud", reason: "Audience claim failed")
        case is IssuerClaim.Type:
            return JWTError(identifier: "iss", reason: "Issuer claim failed")
        case is SubjectClaim.Type:
            return JWTError(identifier: "sub", reason: "Subject claim failed")
        case is AuthTimeClaim.Type:
            return JWTError(identifier: "auth_time", reason: "Authentication time claim failed")
        default: return JWTError(identifier: "error", reason: "Claim failed")
        }
    }
}
