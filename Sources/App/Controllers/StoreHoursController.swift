import Vapor
import Fluent
import FluentPostgreSQL

final class StoreHoursController {
    let calendar = Calendar(identifier: .gregorian)
    
    let queryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.queryDateFormat
        return formatter
    }()
    
    private struct Constants {
        static let queryDateFormat = "M-d-yyyy"
    }
    
    // MARK: - GET
    private func get(_ req: Request) -> Future<StoreDateHoursResponseData> {
        var date = Date()
        if let reqQuery = try? req.query.decode(GetStoreHoursRequestQueryData.self) {
            if let queryDateString = reqQuery.date,
                let queryDate = queryDateFormatter.date(from: queryDateString) {
                date = queryDate
            }
        }
        let weekday = calendar.component(.weekday, from: date)
        return StoreHours.find(weekday, on: req).unwrap(or: Abort(.notImplemented))
            .map { self.makeStoreDateHoursResponseData(storeHours: $0, date: date) }
    }
    
    // MARK: - Helper Methods
    private func makeStoreDateHoursResponseData(storeHours: StoreHours, date: Date) -> StoreDateHoursResponseData {
        var openingDate: Date?
        var closingDate: Date?
        if storeHours.isOpen {
            if let openingHour = storeHours.openingHour {
                openingDate = calendar.date(bySettingHour: openingHour, minute: storeHours.openingMinute ?? 0, second: 0, of: date)
            }
            if let closingHour = storeHours.closingHour {
                var generalClosingDate = date
                if storeHours.isClosingNextDay,
                    let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date) {
                    generalClosingDate = tomorrowDate
                }
                closingDate = calendar.date(bySettingHour: closingHour, minute: storeHours.closingMinute ?? 0, second: 0, of: generalClosingDate)
            }
        }
        return StoreDateHoursResponseData(isOpen: storeHours.isOpen, openingDate: openingDate, closingDate: closingDate)
    }
}

extension StoreHoursController: RouteCollection {
    func boot(router: Router) throws {
        let storeHoursRouter = router.grouped("\(AppConstants.version)/storeHours")
        
        // GET /storeHours
        storeHoursRouter.get(use: get)
    }
}

private extension StoreHoursController {
    struct GetStoreHoursRequestQueryData: Content {
        /// Date in `M-d-yyyy` format.
        let date: String?
    }
}

private extension StoreHoursController {
    struct StoreDateHoursResponseData: Content {
        let isOpen: Bool
        let openingDate: Date?
        let closingDate: Date?
    }
}
