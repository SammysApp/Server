import Vapor
import Fluent
import FluentPostgreSQL

final class ConstructedItemController {
    private let verifier = UserRequestVerifier()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }
            .flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    private func getItems(_ req: Request) throws -> Future<[ItemResponseData]> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem -> Future<[(CategoryItem, Item)]> in
                var query = try constructedItem.categoryItems.query(on: req)
                if let reqQuery = try? req.query.decode(GetItemsQueryRequestData.self) {
                    if let categoryID = reqQuery.categoryID {
                        query = query.filter(\.categoryID == categoryID)
                    }
                }
                return query.join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self).all()
            }.map(makeItemResponseDataArray)
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateConstructedItemRequestData) throws -> Future<ConstructedItemResponseData> {
        return try verified(data, req: req)
            .then { ConstructedItem(categoryID: $0.categoryID, userID: $0.userID).create(on: req) }
            .flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    private func attachCategoryItems(_ req: Request, data: AttachCategoryItemsRequestData) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem in
                CategoryItem.query(on: req).filter(\.id ~~ data.categoryItemIDs).all()
                    .then { constructedItem.categoryItems.attachAll($0, on: req) }
                    .transform(to: constructedItem)
            }.flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    // MARK: - PUT
    private func update(_ req: Request, constructedItem: ConstructedItem) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(ConstructedItem.self).flatMap { existing in
            constructedItem.id = try existing.requireID()
            if let userID = constructedItem.userID {
                return try self.verify(userID, req: req)
                    .then { constructedItem.update(on: req) }
            } else { return constructedItem.update(on: req) }
        }.flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    // MARK: - PATCH
    private func partiallyUpdateConstructedItem(_ req: Request, data: PartialConstructedItemUpdateRequestData) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(ConstructedItem.self).flatMap { constructedItem in
            if let userID = data.userID {
                // Only allow update to `userID` if the current value is `nil` or the same.
                guard constructedItem.userID == nil || constructedItem.userID == userID
                    else { throw Abort(.unauthorized) }
                constructedItem.userID = userID
            }
            if let isFavorite = data.isFavorite { constructedItem.isFavorite = isFavorite }
            if let userID = constructedItem.userID {
                return try self.verify(userID, req: req)
                    .then { constructedItem.update(on: req) }
            } else { return constructedItem.update(on: req) }
        }.flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    // MARK: - DELETE
    private func detachCategoryItem(_ req: Request) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(ConstructedItem.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { constructedItem in
                try req.parameters.next(CategoryItem.self)
                    .then { constructedItem.categoryItems.detach($0, on: req) }
                    .transform(to: constructedItem)
            }.flatMap { try self.makeConstructedItemResponseData(constructedItem: $0, conn: req) }
    }
    
    // MARK: - Helper Methods
    private func getRequirementSatisfied(for constructedItem: ConstructedItem, on conn: DatabaseConnectable) -> Future<Bool> {
        return getMinimumItemsRequirementSatisfied(for: constructedItem, on: conn)
    }
    
    private func getMinimumItemsRequirementSatisfied(for constructedItem: ConstructedItem, on conn: DatabaseConnectable) -> Future<Bool> {
        return guardMinimumItemsRequirementSatisfied(for: constructedItem, on: conn)
            .transform(to: true).catchMap { error in
                if case ConstructedItemControllerError.minimumItemsRequirementNotSatisfied = error { return false }
                else { throw error }
            }
    }
    
    private func guardMinimumItemsRequirementSatisfied(for constructedItem: ConstructedItem, on conn: DatabaseConnectable) -> Future<Void> {
        return constructedItem.category.get(on: conn).flatMap { parentCategory in
            try parentCategory.subcategories.query(on: conn).all().flatMap { categories in
                try categories.map { category in
                    if let minimumItems = category.minimumItems {
                        return try constructedItem.categoryItems.query(on: conn)
                            .filter(\.categoryID == category.requireID()).count()
                            .guard({ $0 >= minimumItems }, else: ConstructedItemControllerError.minimumItemsRequirementNotSatisfied)
                            .transform(to: ())
                    } else { return conn.future() }
                }.flatten(on: conn)
            }
        }
    }
    
    private func makeConstructedItemResponseData(constructedItem: ConstructedItem, conn: DatabaseConnectable) throws -> Future<ConstructedItemResponseData> {
        return try constructedItem.totalPrice(on: conn)
            .and(getRequirementSatisfied(for: constructedItem, on: conn))
            .map { totalPrice, isRequirementsSatisfied in
                try ConstructedItemResponseData(
                    id: constructedItem.requireID(),
                    categoryID: constructedItem.categoryID,
                    userID: constructedItem.userID,
                    totalPrice: totalPrice,
                    isFavorite: constructedItem.isFavorite,
                    isRequirementsSatisfied: isRequirementsSatisfied
                )
            }
    }
    
    private func makeItemResponseDataArray(categoryItemItemPairs: [(CategoryItem, Item)]) throws -> [ItemResponseData] {
        return try categoryItemItemPairs.map(makeItemResponseData)
    }
    
    private func makeItemResponseData(categoryItem: CategoryItem, item: Item) throws -> ItemResponseData {
        return try ItemResponseData(
            id: item.requireID(),
            categoryItemID: categoryItem.requireID(),
            name: item.name
        )
    }
    
    private func verified(_ constructedItem: ConstructedItem, req: Request) throws -> Future<ConstructedItem> {
        guard let userID = constructedItem.userID else { return req.future(constructedItem) }
        return try verify(userID, req: req).transform(to: constructedItem)
    }
    
    private func verified(_ data: CreateConstructedItemRequestData, req: Request) throws -> Future<CreateConstructedItemRequestData> {
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
        // GET /constructedItems/:constructedItem/items
        constructedItemsRouter.get(ConstructedItem.parameter, "items", use: getItems)
        
        // POST /constructedItems
        constructedItemsRouter.post(CreateConstructedItemRequestData.self, use: create)
        // POST /constructedItems/:constructedItem/items
        constructedItemsRouter.post(AttachCategoryItemsRequestData.self, at: ConstructedItem.parameter, "items", use: attachCategoryItems)
        
        // PUT /constructedItems/:constructedItem
        constructedItemsRouter.put(ConstructedItem.self, at: ConstructedItem.parameter, use: update)
        
        // PATCH /constructedItems/:constructedItem
        constructedItemsRouter.patch(PartialConstructedItemUpdateRequestData.self, at: ConstructedItem.parameter, use: partiallyUpdateConstructedItem)
        
        // DELETE /constructedItems/:constructedItem/items/:categoryItem
        constructedItemsRouter.delete(ConstructedItem.parameter, "items", CategoryItem.parameter, use: detachCategoryItem)
    }
}

private extension ConstructedItemController {
    struct GetItemsQueryRequestData: Content {
        let categoryID: Category.ID?
    }
}

private extension ConstructedItemController {
    struct CreateConstructedItemRequestData: Content {
        let categoryID: Category.ID
        let userID: User.ID?
    }
    
    struct AttachCategoryItemsRequestData: Content {
        let categoryItemIDs: [CategoryItem.ID]
    }
}

private extension ConstructedItemController {
    struct PartialConstructedItemUpdateRequestData: Content {
        let userID: User.ID?
        let isFavorite: Bool?
    }
}

private extension ConstructedItemController {
    struct ConstructedItemResponseData: Content {
        let id: ConstructedItem.ID
        let categoryID: Category.ID
        let userID: User.ID?
        let totalPrice: Int
        let isFavorite: Bool
        let isRequirementsSatisfied: Bool
    }
    
    struct ItemResponseData: Content {
        let id: Item.ID
        let categoryItemID: CategoryItem.ID?
        let name: String
    }
}

enum ConstructedItemControllerError: Error {
    case minimumItemsRequirementNotSatisfied
}
