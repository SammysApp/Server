import Vapor

protocol Endpoint {
    var endpoint: (HTTPMethod, URLRepresentable) { get }
}

extension Client {
    func send(_ endpoint: Endpoint, beforeSend: ((Request) throws -> ()) = { _ in }) -> Future<Response> {
        return send(endpoint.endpoint.0, to: endpoint.endpoint.1, beforeSend: beforeSend)
    }
}
