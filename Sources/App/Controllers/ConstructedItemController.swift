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
            .flatMap { try self.categorizedItemsCreator.create(for: $0, on: req) }.map { categorizedItems in
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
    
    private func attachCategoryItems(_ req: Request, data: AttachCategoryItemsData) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem in
                CategoryItem.query(on: req).filter(\.id ~~ data.categoryItemIDs).all()
                    .then { constructedItem.categoryItems.attachAll($0, on: req) }
                    .transform(to: constructedItem)
            }.flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    // MARK: - PUT
    private func update(_ req: Request, constructedItem: ConstructedItem) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self).flatMap { existing in
            constructedItem.id = try existing.requireID()
            if let userID = constructedItem.userID {
                return try self.verify(userID, req: req)
                    .then { constructedItem.update(on: req) }
            } else { return constructedItem.update(on: req) }
        }.flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    // MARK: - PATCH
    private func partiallyUpdateConstructedItem(_ req: Request, data: PartialConstructedItemUpdateData) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self).flatMap { constructedItem in
            if let isFavorite = data.isFavorite {
                constructedItem.isFavorite = isFavorite
            }
            if let userID = constructedItem.userID {
                return try self.verify(userID, req: req)
                    .then { constructedItem.update(on: req) }
            } else { return constructedItem.update(on: req) }
        }.flatMap { try self.makeConstructedItemData(constructedItem: $0, req: req) }
    }
    
    // MARK: - DELETE
    private func detachCategoryItem(_ req: Request) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem in
                try req.parameters.next(CategoryItem.self)
                    .then { constructedItem.categoryItems.detach($0, on: req) }
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
        constructedItemsRouter.post(AttachCategoryItemsData.self, at: ConstructedItem.parameter, "items", use: attachCategoryItems)
        
        // PUT /constructedItems/:constructedItem
        constructedItemsRouter.put(ConstructedItem.self, at: ConstructedItem.parameter, use: update)
        
        // PATCH /constructedItems/:constructedItem
        constructedItemsRouter.patch(PartialConstructedItemUpdateData.self, at: ConstructedItem.parameter, use: partiallyUpdateConstructedItem)
        
        // DELETE /constructedItems/:constructedItem/items/:categoryItem
        constructedItemsRouter.delete(ConstructedItem.parameter, "items", CategoryItem.parameter, use: detachCategoryItem)
    }
}

private extension ConstructedItemController {
    struct ConstructedItemData: Content {
        var id: ConstructedItem.ID
        var categoryID: Category.ID
        var userID: User.ID?
        var totalPrice: Int
        var isFavorite: Bool
        
        init(constructedItem: ConstructedItem, totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.totalPrice = totalPrice
            self.isFavorite = constructedItem.isFavorite
        }
    }
}

private extension ConstructedItemController {
    struct CreateData: Content {
        let categoryID: Category.ID
        let userID: User.ID?
    }
    
    struct AttachCategoryItemsData: Content {
        let categoryItemIDs: [CategoryItem.ID]
    }
    
    struct PartialConstructedItemUpdateData: Content {
        let isFavorite: Bool?
    }
}
