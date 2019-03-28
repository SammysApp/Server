import Vapor

extension Client {
    func send(_ endpoint: HTTPEndpoint,
              headers: [HTTPHeader] = [],
              beforeSend: ((Request) throws -> ()) = { _ in }) -> Future<Response> {
        return self.send(endpoint.endpoint.0, headers: .init(headers), to: endpoint.fullURLString, beforeSend: beforeSend)
    }
}
