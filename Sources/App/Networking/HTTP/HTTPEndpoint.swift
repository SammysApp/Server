import Vapor

typealias URLPath = String

protocol HTTPEndpoint {
    var baseURLString: String { get }
    var endpoint: (HTTPMethod, URLPath) { get }
}

extension HTTPEndpoint{
    var fullURLString: URLRepresentable { return self.baseURLString + self.endpoint.1 }
}
