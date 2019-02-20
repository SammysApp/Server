import Vapor

protocol ClientEndpoint {
    var data: ClientEndpointData { get }
}

struct ClientEndpointData {
    let method: HTTPMethod
    let url: URLRepresentable
}

extension Client {
    func send(_ endpoint: ClientEndpoint, beforeSend: ((Request) throws -> ()) = { _ in }) -> Future<Response> {
        return send(endpoint.data.method, to: endpoint.data.url, beforeSend: beforeSend)
    }
}

extension ClientEndpoint {
    func send(on client: Client, beforeSend: ((Request) throws -> ()) = { _ in }) -> Future<Response> {
        return client.send(self, beforeSend: beforeSend)
    }
}
