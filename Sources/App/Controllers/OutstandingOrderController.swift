import Vapor
import Fluent
import FluentPostgreSQL

final class OutstandingOrderController {
    private let verifier = UserRequestVerifier()
    
    // MARK: - GET
    private func getOne(_ req: Request) throws -> Future<OutstandingOrderResponseData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .flatMap { try self.makeOutstandingOrderResponseData(outstandingOrder: $0, conn: req) }
    }
    
    private func getConstructedItems(_ req: Request) throws -> Future<[ConstructedItemResponseData]> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { outstandingOrder in
                try outstandingOrder.constructedItems.query(on: req)
                .alsoDecode(OutstandingOrderConstructedItem.self).all()
            }.flatMap { result in
                try result.map { try self.makeConstructedItemResponseData(constructedItem: $0, outstandingOrderConstructedItem: $1, conn: req) }.flatten(on: req)
            }
    }
    
    // MARK: - POST
    private func create(_ req: Request, data: CreateOutstandingOrderRequestData) throws -> Future<OutstandingOrderResponseData> {
        return try verified(data, req: req)
            .then { OutstandingOrder(userID: $0.userID).create(on: req) }
            .flatMap { try self.makeOutstandingOrderResponseData(outstandingOrder: $0, conn: req) }
    }
    
    private func attachConstructedItems(_ req: Request, data: AttachConstructedItemsRequestData) throws -> Future<OutstandingOrderResponseData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(ConstructedItem.query(on: req).filter(\.id ~~ data.ids).all())
            .then { $0.constructedItems.attachAll($1, on: req).transform(to: $0) }
            .flatMap { try self.makeOutstandingOrderResponseData(outstandingOrder: $0, conn: req) }
    }
    
    // MARK: - PUT
    private func update(_ req: Request, outstandingOrder: OutstandingOrder) throws -> Future<OutstandingOrderResponseData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }.flatMap { existing in
            outstandingOrder.id = try existing.requireID()
            if let userID = outstandingOrder.userID {
                return try self.verify(userID, req: req)
                    .then { outstandingOrder.update(on: req) }
                    .flatMap { try self.updateConstructedItems(of: $0, with: userID, on: req) }
            } else { return outstandingOrder.update(on: req) }
        }.flatMap { try self.makeOutstandingOrderResponseData(outstandingOrder: $0, conn: req) }
    }
    
    // MARK: - PATCH
    private func partiallyUpdateConstructedItem(_ req: Request, data: PartialConstructedItemUpdateRequestData) throws -> Future<ConstructedItemResponseData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(req.parameters.next(ConstructedItem.self))
            .flatMap { try $0.pivot(attaching: $1, on: req).unwrap(or: Abort(.badRequest)).and(result: $1) }
            .flatMap { pivot, constructedItem in
                if let quantity = data.quantity { pivot.quantity = quantity }
                return try pivot.update(on: req)
                    .transform(to: self.makeConstructedItemResponseData(constructedItem: constructedItem, outstandingOrderConstructedItem: pivot, conn: req))
            }
    }
    
    // MARK: - DELETE
    private func removeConstructedItem(_ req: Request) throws -> Future<OutstandingOrderResponseData> {
        return try req.parameters.next(OutstandingOrder.self)
            .flatMap { try self.verified($0, req: req) }
            .and(req.parameters.next(ConstructedItem.self))
            .flatMap { try $0.constructedItems.detach($1, on: req)
                .transform(to: self.makeOutstandingOrderResponseData(outstandingOrder: $0, conn: req)) }
    }
    
    // MARK: - Helper Methods
    private func updateConstructedItems(of outstandingOrder: OutstandingOrder, with userID: User.ID, on conn: DatabaseConnectable) throws -> Future<OutstandingOrder> {
        return try outstandingOrder.constructedItems.query(on: conn).all().flatMap { constructedItems in
            constructedItems.map { constructedItem in
                constructedItem.userID = userID
                return constructedItem.update(on: conn).transform(to: ())
            }.flatten(on: conn).transform(to: outstandingOrder)
        }
    }
    
    private func makeOutstandingOrderResponseData(outstandingOrder: OutstandingOrder, conn: DatabaseConnectable) throws -> Future<OutstandingOrderResponseData> {
        return try outstandingOrder.totalPrice(on: conn).map { totalPrice in
            let taxPrice = Int((Double(totalPrice) * AppConstants.taxRateMultiplier).rounded())
            return try OutstandingOrderResponseData(
                id: outstandingOrder.requireID(),
                userID: outstandingOrder.userID,
                preparedForDate: outstandingOrder.preparedForDate,
                note: outstandingOrder.note,
                totalPrice: totalPrice,
                taxPrice: taxPrice
            )
        }
    }
    
    private func makeConstructedItemResponseData(constructedItem: ConstructedItem, outstandingOrderConstructedItem: OutstandingOrderConstructedItem, conn: DatabaseConnectable) throws -> Future<ConstructedItemResponseData> {
        return try constructedItem.name(on: conn)
            .and(constructedItem.description(on: conn))
            .and(constructedItem.totalPrice(on: conn)).map { result in
                let ((name, description), totalPrice) = result
                return try ConstructedItemResponseData(
                    id: constructedItem.requireID(),
                    categoryID: constructedItem.categoryID,
                    userID: constructedItem.userID,
                    name: name,
                    description: description,
                    quantity: outstandingOrderConstructedItem.quantity,
                    totalPrice: totalPrice * outstandingOrderConstructedItem.quantity,
                    isFavorite: constructedItem.isFavorite
                )
            }
    }
    
    private func verified(_ outstandingOrder: OutstandingOrder, req: Request) throws -> Future<OutstandingOrder> {
        guard let userID = outstandingOrder.userID else { return req.future(outstandingOrder) }
        return try verify(userID, req: req).transform(to: outstandingOrder)
    }
    
    private func verified(_ data: CreateOutstandingOrderRequestData, req: Request) throws -> Future<CreateOutstandingOrderRequestData> {
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
        outstandingOrdersRouter.post(CreateOutstandingOrderRequestData.self, use: create)
        // POST /outstandingOrders/:outstandingOrder/constructedItems
        outstandingOrdersRouter.post(AttachConstructedItemsRequestData.self, at: OutstandingOrder.parameter, "constructedItems", use: attachConstructedItems)
        
        // PUT /outstandingOrders/:outstandingOrder
        outstandingOrdersRouter.put(OutstandingOrder.self, at: OutstandingOrder.parameter, use: update)
        
        // PATCH /outstandingOrders/:outstandingOrder/constructedItems/:constructedItem
        outstandingOrdersRouter.patch(PartialConstructedItemUpdateRequestData.self, at: OutstandingOrder.parameter, "constructedItems", ConstructedItem.parameter, use: partiallyUpdateConstructedItem)
    
        // DELETE /outstandingOrders/:outstandingOrder/constructedItems/:constructedItem
        outstandingOrdersRouter.delete(OutstandingOrder.parameter, "constructedItems", ConstructedItem.parameter, use: removeConstructedItem)
    }
}

private extension OutstandingOrderController {
    struct CreateOutstandingOrderRequestData: Content {
        let userID: User.ID?
    }
    
    struct AttachConstructedItemsRequestData: Content {
        let ids: [ConstructedItem.ID]
    }
}

private extension OutstandingOrderController {
    struct PartialConstructedItemUpdateRequestData: Content {
        let quantity: Int?
    }
}

private extension OutstandingOrderController {
    struct OutstandingOrderResponseData: Content {
        let id: OutstandingOrder.ID
        let userID: User.ID?
        let preparedForDate: Date?
        let note: String?
        let totalPrice: Int
        let taxPrice: Int
    }
    
    struct ConstructedItemResponseData: Content {
        let id: ConstructedItem.ID
        let categoryID: Category.ID
        let userID: User.ID?
        let name: String
        let description: String
        let quantity: Int
        let totalPrice: Int
        let isFavorite: Bool
    }
}
