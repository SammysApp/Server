import Vapor
import Fluent
import FluentPostgreSQL

final class OfferController {
    // MARK: - GET
    func getOneCode(_ req: Request) throws -> Future<Offer> {
        return try Offer.query(on: req).filter(\.code == req.parameters.next(String.self))
            .first().unwrap(or: Abort(.badRequest))
    }
    
    // MARK: - POST
    func create(_ req: Request, offer: Offer) throws -> Future<Offer> {
        return offer.create(on: req)
    }
}

extension OfferController: RouteCollection {
    func boot(router: Router) throws {
        let offerRouter = router.grouped("\(AppConstants.version)/offers")
        
        // GET /offers/:code
        offerRouter.get(String.parameter, use: getOneCode)
        
        // POST /offers
        offerRouter.post(Offer.self, use: create)
    }
}
