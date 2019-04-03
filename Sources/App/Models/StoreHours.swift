import Vapor
import FluentPostgreSQL

final class StoreHours: Model {
    typealias Database = PostgreSQLDatabase
    typealias ID = Int
    
    static var idKey: IDKey { return \.weekday }
    
    var weekday: Int?
    var openingHour: Int?
    var openingMinute: Int?
    var closingHour: Int?
    var closingMinute: Int?
    var isOpen: Bool
    var isClosingNextDay: Bool
    
    init(weekday: Int,
         openingHour: Int?,
         openingMinute: Int?,
         closingHour: Int?,
         closingMinute: Int?,
         isOpen: Bool = true,
         isClosingNextDay: Bool = false) {
        self.weekday = weekday
        self.openingHour = openingHour
        self.openingMinute = openingMinute
        self.closingHour = closingHour
        self.closingMinute = closingMinute
        self.isOpen = isOpen
        self.isClosingNextDay = isClosingNextDay
    }
}

extension StoreHours: Content {}
extension StoreHours: Migration {}
