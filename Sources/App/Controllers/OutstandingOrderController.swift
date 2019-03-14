import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
    private let verifier = UserRequestVerifier()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<OutstandingOrderData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .flatMap { try self.makeOutstandingOrderData(outstandingOrder: $0, req: req) }
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[ConstructedItemData]> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }.flatMap {
                try $0.constructedItems.query(on: req)
                .alsoDecode(OutstandingOrderConstructedItem.self).all() }.flatMap { pairs in
                try pairs.map { try self.makeConstructedItemData(constructedItem: $0, outstandingOrderConstructedItem: $1, req: req) }.flatten(on: req)
            }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateData) throws -> Future<OutstandingOrderData> {
        return try verified(data, req: req)
            .then { OutstandingOrder(userID: $0.userID).create(on: req) }
            .flatMap { try self.makeOutstandingOrderData(outstandingOrder: $0, req: req) }
    }
    
    private func attachConstructedItems(_ req: Request, data: AttachConstructedItemsData) throws -> Future<OutstandingOrderData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(ConstructedItem.query(on: req).filter(\.id ~~ data.ids).all())
            .then { $0.constructedItems.attachAll($1, on: req).transform(to: $0) }
            .flatMap { try self.makeOutstandingOrderData(outstandingOrder: $0, req: req) }
    }
    
    // MARK: - PUT
    private func update(_ req: Request, outstandingOrder: OutstandingOrder) throws -> Future<OutstandingOrderData> {
        return try req.parameters.next(OutstandingOrder.self).flatMap { existing in
            outstandingOrder.id = try existing.requireID()
            if let userID = outstandingOrder.userID {
                return try self.verify(userID, req: req)
                    .then { outstandingOrder.update(on: req) }
            } else { return outstandingOrder.update(on: req) }
        }.flatMap { try self.makeOutstandingOrderData(outstandingOrder: $0, req: req) }
    }
    
    // MARK: - PATCH
    private func partiallyUpdateConstructedItem(_ req: Request, data: PartialConstructedItemUpdateData) throws -> Future<ConstructedItemData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(req.parameters.next(ConstructedItem.self))
            .flatMap { try $0.pivot(attaching: $1, on: req).and(result: $1) }.flatMap { pivot, constructedItem in
                guard let pivot = pivot else { throw Abort(.badRequest) }
                if let quantity = data.quantity { pivot.quantity = quantity }
                return try pivot.update(on: req).transform(to: self.makeConstructedItemData(constructedItem: constructedItem, outstandingOrderConstructedItem: pivot, req: req))
            }
    }
    
    // MARK: - DELETE
    private func removeConstructedItem(_ req: Request) throws -> Future<OutstandingOrderData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(req.parameters.next(ConstructedItem.self))
            .flatMap { try $0.constructedItems.detach($1, on: req).transform(to: self.makeOutstandingOrderData(outstandingOrder: $0, req: req)) }
    }
    
    // MARK: - Helper Methods
    private func makeOutstandingOrderData(outstandingOrder: OutstandingOrder, req: Request) throws -> Future<OutstandingOrderData> {
        return try outstandingOrder.totalPrice(on: req)
            .map { try OutstandingOrderData(outstandingOrder: outstandingOrder, totalPrice: $0) }
    }
    
    private func makeConstructedItemData(constructedItem: ConstructedItem, outstandingOrderConstructedItem: OutstandingOrderConstructedItem, req: Request) throws -> Future<ConstructedItemData> {
        return try constructedItem.name(on: req)
            .and(constructedItem.description(on: req))
            .and(constructedItem.totalPrice(on: req))
            .map { tuple in
                let ((name, description), totalPrice) = tuple
                return try ConstructedItemData(
                    constructedItem: constructedItem,
                    outstandingOrderConstructedItem: outstandingOrderConstructedItem,
                    name: name,
                    description: description,
                    totalPrice: totalPrice * outstandingOrderConstructedItem.quantity
                )
            }
    }
    
    private func verified(_ outstandingOrder: OutstandingOrder, req: Request) throws -> Future<OutstandingOrder> {
        guard let userID = outstandingOrder.userID else { return req.future(outstandingOrder) }
        return try verify(userID, req: req).transform(to: outstandingOrder)
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

extension OutstandingOrderController: RouteCollection {
    func boot(router: Router) throws {
        let outstandingOrdersRouter = router
            .grouped("\(AppConstants.version)/outstandingOrders")
        
        // GET /outstandingOrders/:outstandingOrder
        outstandingOrdersRouter.get(OutstandingOrder.parameter, use: getOne)
        // GET /outstandingOrders/:outstandingOrder/constructedItems
        outstandingOrdersRouter.get(OutstandingOrder.parameter, "constructedItems", use: getConstructedItems)
        
        // POST /outstandingOrders
        outstandingOrdersRouter.post(CreateData.self, use: create)
        // POST /outstandingOrders/:outstandingOrder/constructedItems
        outstandingOrdersRouter.post(AttachConstructedItemsData.self, at: OutstandingOrder.parameter, "constructedItems", use: attachConstructedItems)
        
        // PUT /outstandingOrders/:outstandingOrder
        outstandingOrdersRouter.put(OutstandingOrder.self, at: OutstandingOrder.parameter, use: update)
        
        // PATCH /outstandingOrders/:outstandingOrder/constructedItems/:constructedItem
        outstandingOrdersRouter.patch(PartialConstructedItemUpdateData.self, at: OutstandingOrder.parameter, "constructedItems", ConstructedItem.parameter, use: partiallyUpdateConstructedItem)
    
        // DELETE /outstandingOrders/:outstandingOrder/constructedItems/:constructedItem
        outstandingOrdersRouter.delete(OutstandingOrder.parameter, "constructedItems", ConstructedItem.parameter, use: removeConstructedItem)
    }
}

private extension OutstandingOrderController {
    struct CreateData: Content {
        let userID: User.ID?
    }
    
    struct AttachConstructedItemsData: Content {
        let ids: [ConstructedItem.ID]
    }
    
    struct PartialConstructedItemUpdateData: Content {
        let quantity: Int?
    }
}

private extension OutstandingOrderController {
    struct OutstandingOrderData: Content {
        let id: OutstandingOrder.ID
        let preparedForDate: Date?
        let note: String?
        let totalPrice: Int
        
        init(outstandingOrder: OutstandingOrder, totalPrice: Int) throws {
            self.id = try outstandingOrder.requireID()
            self.preparedForDate = outstandingOrder.preparedForDate
            self.note = outstandingOrder.note
            self.totalPrice = totalPrice
        }
    }
    
    struct ConstructedItemData: Content {
        let id: ConstructedItem.ID
        let categoryID: Category.ID
        let userID: User.ID?
        let name: String
        let description: String
        let quantity: Int
        let totalPrice: Int
        let isFavorite: Bool
        
        init(constructedItem: ConstructedItem,
             outstandingOrderConstructedItem: OutstandingOrderConstructedItem,
             name: String,
             description: String,
             totalPrice: Int) throws {
            self.id = try constructedItem.requireID()
            self.categoryID = constructedItem.categoryID
            self.userID = constructedItem.userID
            self.name = name
            self.description = description
            self.quantity = outstandingOrderConstructedItem.quantity
            self.totalPrice = totalPrice
            self.isFavorite = constructedItem.isFavorite
        }
    }
}

