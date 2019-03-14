import Vapor
import FluentPostgreSQL
import Stripe

final class User: PostgreSQLUUIDModel {
    typealias UID = String
    
    var id: User.ID?
    var uid: UID
    var customerID: String
    var email: String
    var firstName: String
    var lastName: String
    
    init(id: User.ID? = nil,
         uid: UID,
         customerID: String,
         email: String,
         firstName: String,
         lastName: String) {
        self.id = id
        self.uid = uid
        self.customerID = customerID
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
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
