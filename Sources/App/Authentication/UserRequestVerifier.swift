import Vapor
import JWT

struct UserRequestVerifier {
    private let google = GoogleAPIManager()
    
    /// Verifies a user's request based on their Firebase JWT token.
    /// Returns their Firebase UID.
    func verify(_ req: Request) throws -> Future<User.UID> {
        guard let bearer = req.http.headers.bearerAuthorization
            else { throw Abort(.unauthorized) }
        return try google.publicKeys(req.client()).thenThrowing { keys -> JWTSigners in
            let signers = JWTSigners()
            try keys.forEach { try signers.use(.rs256(key: .public(certificate: $1)), kid: $0) }
            return signers
        }.thenThrowing { try JWT<UserUIDPayload>(from: bearer.token, verifiedUsing: $0).payload.uid }
    }
}
