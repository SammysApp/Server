import Vapor

struct HTTPHeader {
    let name: HTTPHeaderName
    let value: HTTPHeaderValue
}

extension HTTPHeaders {
    init(_ headers: [HTTPHeader]) {
        self.init(headers.map { ($0.name.rawValue, $0.value.rawValue) })
    }
}
