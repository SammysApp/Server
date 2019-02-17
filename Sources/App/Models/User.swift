import Vapor
import FluentPostgreSQL

final class User: PostgreSQLUUIDModel {
    typealias UID = String
    
    var id: User.ID?
    var uid: UID
    var customerID: String
    var email: String
    var name: String
    
    init(id: User.ID? = nil,
         uid: UID,
         customerID: String,
         email: String,
         name: String) {
        self.id = id
        self.uid = uid
        self.customerID = customerID
        self.email = email
        self.name = name
    }
}

extension User: Parameter {}
extension User: Content {}
extension User: Migration {}

extension User {
    var constructedItems: Children<User, ConstructedItem> {
        return children(\.userID)
    }
}

extension User {
    var outstandingOrders: Children<User, OutstandingOrder> {
        return children(\.userID)
    }
}
