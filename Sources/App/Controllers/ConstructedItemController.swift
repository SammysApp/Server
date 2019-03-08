import Vapor
import Fluent
import FluentPostgreSQL

final class ConstructedItemController {
    private let verifier = UserRequestVerifier()
    private let categorizedItemsCreator = ConstructedItemCategorizedItemsCreator()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }
            .flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    private func getCategorizedItems(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }
            .flatMap { try self.categorizedItemsCreator.create(for: $0, on: req) }
            .map { categorizedItems in
                let res = req.response()
                try res.content.encode(json: categorizedItems)
                return res
            }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateData) throws -> Future<ConstructedItemData> {
        return try verified(data, req: req)
            .then { ConstructedItem(categoryID: $0.categoryID, userID: $0.userID).create(on: req) }
            .flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    private func attachItems(_ req: Request, data: AttachItemsData) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem in
                CategoryItem.query(on: req).filter(\.id ~~ data.categoryItemIDs).all()
                    .then { constructedItem.categoryItems.attachAll($0, on: req) }
                    .transform(to: constructedItem)
            }.flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    // MARK: - Helper Methods
    private func makeConstructedItemData(constructedItem: ConstructedItem, req: Request) throws -> Future<ConstructedItemData> {
        return try constructedItem.totalPrice(on: req)
            .map { try ConstructedItemData(constructedItem: constructedItem, totalPrice: $0) }
    }
    
    private func verified(_ constructedItem: ConstructedItem, req: Request) throws -> Future<ConstructedItem> {
        guard let userID = constructedItem.userID else { return req.future(constructedItem) }
        return try verify(userID, req: req).transform(to: constructedItem)
    }
    
    private func verified(_ data: CreateData, req: Request) throws -> Future<CreateData> {
        guard let userID = data.userID else { return req.future(data) }
        return try verify(userID, req: req).transform(to: data)
    }
    
    private func verify(_ userID: User.ID, req: Request) throws -> Future<Void> {
        return User.find(userID, on: req).unwrap(or: Abort(.badRequest))
            .and(try verifier.verify(req))
            .guard({ $0.uid == $1 }, else: Abort(.unauthorized)).transform(to: ())
    }
}

extension ConstructedItemController: RouteCollection {
    func boot(router: Router) throws {
        let constructedItemsRouter =
            router.grouped("\(AppConstants.version)/constructedItems")
        
        // GET /constructedItems/:constructedItem
        constructedItemsRouter.get(ConstructedItem.parameter, use: getOne)
        // GET /constructedItems/:constructedItem/categorizedItems
        constructedItemsRouter.get(ConstructedItem.parameter, "categorizedItems", use: getCategorizedItems)
        
        // POST /constructedItems
        constructedItemsRouter.post(CreateData.self, use: create)
        // POST /constructedItems/:constructedItem/items
        constructedItemsRouter.post(AttachItemsData.self, at: ConstructedItem.parameter, "items", use: attachItems)
    }
}

private extension ConstructedItemController {
    struct CreateData: Content {
        let categoryID: Category.ID
        let userID: User.ID?
    }
    
    struct AttachItemsData: Content {
        let categoryItemIDs: [CategoryItem.ID]
    }
}

private extension ConstructedItemController {
    struct ConstructedItemData: Content {
        var id: ConstructedItem.ID
        var categoryID: Category.ID
        var userID: User.ID?
        var isFavorite: Bool
        var totalPrice: Int
        
        init(constructedItem: ConstructedItem, totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.isFavorite = constructedItem.isFavorite
            self.totalPrice = totalPrice
        }
    }
}
