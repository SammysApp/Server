import Vapor
import Fluent
import FluentPostgreSQL

final class CategoryController {
    // MARK: - GET
    private func get(_ req: Request) -> Future<[CategoryResponseData]> {
        var databaseQuery = Category.query(on: req)
        if let reqQuery = try? req.query.decode(GetCategoriesRequestQueryData.self) {
            if let isRoot = reqQuery.isRoot, isRoot {
                databaseQuery = databaseQuery.filter(\.parentCategoryID == nil)
            }
        }
        return databaseQuery.all()
            .flatMap { try self.makeCategoryResponseDataArray(categories: $0, conn: req) }
    }
    
    private func getOne(_ req: Request) throws -> Future<Category> {
        return try req.parameters.next(Category.self)
    }
    
    private func getSubcategories(_ req: Request) throws -> Future<[CategoryResponseData]> {
        return try req.parameters.next(Category.self)
            .flatMap { try $0.subcategories.query(on: req).all() }
            .flatMap { try self.makeCategoryResponseDataArray(categories: $0, conn: req) }
    }
    
    private func getItems(_ req: Request) throws -> Future<[ItemResponseData]> {
        return try req.parameters.next(Category.self)
            .flatMap { try $0.items.query(on: req).alsoDecode(CategoryItem.self).all() }
            .flatMap { try self.makeItemResponseDataArray(itemCategoryItemPairs: $0, conn: req) }
            .map { $0.sorted() }
    }
    
    private func getItemModifiers(_ req: Request) throws -> Future<[Modifier]> {
        return try req.parameters.next(Category.self)
            .and(try req.parameters.next(Item.self)).flatMap {
                try $0.pivot(attaching: $1, on: req)
                .unwrap(or: Abort(.badRequest))
                .flatMap { try $0.modifiers.query(on: req).all() }
            }
    }
    
    // MARK: - Helper Methods
    private func makeCategoryResponseDataArray(categories: [Category], conn: DatabaseConnectable) throws -> Future<[CategoryResponseData]> {
        return try categories.map { category in
            try category.subcategories.query(on: conn)
                .count().map { $0 > 0 }.thenThrowing { isParentCategory in
                    try CategoryResponseData(
                        id: category.requireID(),
                        parentCategoryID: category.parentCategoryID,
                        name: category.name,
                        imageURL: category.imageURL,
                        minimumItems: category.minimumItems,
                        maximumItems: category.maximumItems,
                        isParentCategory: isParentCategory,
                        isConstructable: category.isConstructable
                    )
                }
        }.flatten(on: conn)
    }
    
    private func makeItemResponseDataArray(itemCategoryItemPairs: [(Item, CategoryItem)], conn: DatabaseConnectable) throws -> Future<[ItemResponseData]> {
        return try itemCategoryItemPairs
            .map { try self.makeItemResponseData(item: $0, categoryItem: $1, conn: conn) }
            .flatten(on: conn)
    }
    
    private func makeItemResponseData(item: Item, categoryItem: CategoryItem, conn: DatabaseConnectable) throws -> Future<ItemResponseData> {
        return try categoryItem.modifiers.query(on: conn)
            .count().map { $0 > 0 }.thenThrowing { isModifiable in
                try ItemResponseData(
                    id: item.requireID(),
                    categoryItemID: categoryItem.requireID(),
                    name: item.name,
                    description: categoryItem.description,
                    price: categoryItem.price,
                    isModifiable: isModifiable
                )
            }
    }
}

extension CategoryController: RouteCollection {
    func boot(router: Router) throws {
        let categoriesRouter = router.grouped("\(AppConstants.version)/categories")
        
        // GET /categories
        categoriesRouter.get(use: get)
        // GET /categories/:category
        categoriesRouter.get(Category.parameter, use: getOne)
        // GET /categories/:category/subcategories
        categoriesRouter.get(Category.parameter, "subcategories", use: getSubcategories)
        // GET /categories/:category/items
        categoriesRouter.get(Category.parameter, "items", use: getItems)
        // GET /categories/:category/items/:item/modifiers
        categoriesRouter.get(Category.parameter, "items", Item.parameter, "modifiers", use: getItemModifiers)
    }
}

private extension CategoryController {
    struct GetCategoriesRequestQueryData: Codable {
        let isRoot: Bool?
    }
}

private extension CategoryController {
    struct CategoryResponseData: Content {
        var id: Category.ID
        var parentCategoryID: Category.ID?
        var name: String
        var imageURL: String?
        var minimumItems: Int?
        var maximumItems: Int?
        var isParentCategory: Bool
        var isConstructable: Bool
    }

    struct ItemResponseData: Content {
        let id: Item.ID
        let categoryItemID: CategoryItem.ID?
        let name: String
        let description: String?
        let price: Int?
        let isModifiable: Bool
    }
}

private extension Array where Element == CategoryController.ItemResponseData {
    var isAllPriced: Bool { return allSatisfy { $0.price != nil } }
    
    func sorted() -> [CategoryController.ItemResponseData] {
        if isAllPriced { return sorted { $0.price! < $1.price! } }
        else { return sorted { $0.name < $1.name } }
    }
}
