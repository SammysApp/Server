import Vapor

struct SquareAPIManager {
    private var dataEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    private var dataDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    func retrieveCustomer(id: SquareCustomer.ID, client: Client) -> Future<SquareCustomer> {
        let endpoint = Endpoints.retrieveCustomer(id)
        return client.send(endpoint, headers: makeHeaders(endpoint))
            .flatMap { try $0.content.decode(RetrieveCustomerResponseData.self, using: self.dataDecoder) }
            .map { $0.customer }
    }
    
    func createCustomer(data: CreateCustomerRequestData, client: Client) -> Future<SquareCustomer> {
        let endpoint = Endpoints.createCustomer
        return client.send(endpoint, headers: makeHeaders(endpoint)) {
            try $0.content.encode(data, using: self.dataEncoder)
        }.flatMap { try $0.content.decode(CreateCustomerResponseData.self, using: self.dataDecoder) }
            .map { $0.customer }
    }
    
    func createCustomerCard(id: SquareCustomer.ID, data: CreateCustomerCardRequestData, client: Client) -> Future<SquareCard> {
        let endpoint = Endpoints.createCustomerCard(id)
        return client.send(endpoint, headers: makeHeaders(endpoint)) {
            try $0.content.encode(data, using: self.dataEncoder)
        }.flatMap { try $0.content.decode(CreateCustomerCardResponseData.self, using: self.dataDecoder) }
            .map { $0.card }
    }
    
    func charge(locationID: String, data: ChargeRequestData, client: Client) -> Future<SquareTransaction> {
        let endpoint = Endpoints.charge(locationID)
        return client.send(endpoint, headers: makeHeaders(endpoint)) {
            try $0.content.encode(data, using: self.dataEncoder)
        }.flatMap { try $0.content.decode(ChargeResponseData.self, using: self.dataDecoder) }
            .map { $0.transaction }
    }
    
    private func makeHeaders(_ endpoint: HTTPEndpoint) -> [HTTPHeader] {
        return makeHeaders(endpoint.endpoint.0)
    }
    
    private func makeHeaders(_ method: HTTPMethod) -> [HTTPHeader] {
        var headers = [
            HTTPHeader(name: .authorization, value: .bearerAuthentication(squareAccessToken)),
            HTTPHeader(name: .accept, value: .json)
        ]
        switch method {
        case .PUT, .POST:
            headers.append(HTTPHeader(name: .contentType, value: .json))
            return headers
        default: return headers
        }
    }
}

private extension SquareAPIManager {
    enum Endpoints: HTTPEndpoint {
        /// GET `/customers/:customer`
        case retrieveCustomer(SquareCustomer.ID)
        /// POST `/customers`
        case createCustomer
        /// POST `/customers/:customer/cards`
        case createCustomerCard(SquareCustomer.ID)
        /// POST `/locations/:location/transactions`
        case charge(String)
        
        var baseURLString: String { return "https://connect.squareup.com" }
        var version: String { return "v2" }
        
        var endpoint: (HTTPMethod, URLPath) {
            switch self {
            case .retrieveCustomer(let id):
                return (.GET, "/\(version)/customers/\(id)")
            case .createCustomer:
                return (.POST, "/\(version)/customers")
            case .createCustomerCard(let id):
                return (.POST, "/\(version)/customers/\(id)/cards")
            case .charge(let id):
                return (.POST, "/\(version)/locations/\(id)/transactions")
            }
        }
    }
}

extension SquareAPIManager {
    private struct RetrieveCustomerResponseData: Content {
        let customer: SquareCustomer
    }
}

extension SquareAPIManager {
    struct CreateCustomerRequestData: Content {
        let givenName: String?
        let familyName: String?
        let emailAddress: String?
    }
    
    private struct CreateCustomerResponseData: Codable {
        let customer: SquareCustomer
    }
}

extension SquareAPIManager {
    struct CreateCustomerCardRequestData: Content {
        let cardNonce: String
        let billingAddress: SquareAddress
    }
    
    private struct CreateCustomerCardResponseData: Codable {
        let card: SquareCard
    }
}

extension SquareAPIManager {
    struct ChargeRequestData: Content {
        let idempotencyKey: String
        let amountMoney: SquareMoney
        let cardNonce: String?
        let customerCardID: String?
        let customerID: SquareCustomer.ID?
    }
    
    private struct ChargeResponseData: Codable {
        let transaction: SquareTransaction
    }
}
