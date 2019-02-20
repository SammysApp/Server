import Vapor
import Fluent
import FluentPostgreSQL

final class CategoryController {
    // MARK: - GET
    private func get(_ req: Request) -> Future<[CategoryData]> {
        var databaseQuery = Category.query(on: req)
        if let requestQuery = try? req.query.decode(CategoryQuery.self) {
            if let isRoot = requestQuery.isRoot, isRoot {
                databaseQuery = databaseQuery.filter(\.parentCategoryID == nil)
            }
        }
        return databaseQuery.all()
            .flatMap { try self.makeCategoryDataArray(categories: $0, req: req) }
    }

    private func getOne(_ req: Request) throws -> Future<Category> {
        return try req.parameters.next(Category.self)
    }

    private func getSubcategories(_ req: Request) throws -> Future<[CategoryData]> {
        return try req.parameters.next(Category.self)
            .flatMap { try $0.subcategories.query(on: req).all() }
            .flatMap { try self.makeCategoryDataArray(categories: $0, req: req) }
    }

    private func getItems(_ req: Request) throws -> Future<[ItemData]> {
        return try req.parameters.next(Category.self)
            .flatMap { try $0.items.query(on: req).alsoDecode(CategoryItem.self).all() }
            .flatMap { try self.makeItemDataArray(itemCategoryItemPairs: $0, req: req) }
            .map { $0.sorted() }
    }

    private func getItemModifiers(_ req: Request) throws -> Future<[Modifier]> {
        return try req.parameters.next(Category.self)
            .and(try req.parameters.next(Item.self))
            .flatMap { try $0.pivot(attaching: $1, on: req)
                .unwrap(or: Abort(.badRequest))
                .flatMap { try $0.modifiers.query(on: req).all() } }
    }

    // MARK: - Helper Methods
    private func makeCategoryDataArray(categories: [Category], req: Request) throws
        -> Future<[CategoryData]> {
        return try categories.map { category in
            try category.subcategories.query(on: req)
                .count().map { $0 > 0 }.thenThrowing
                { try CategoryData(category: category, isParentCategory: $0) }
            }.flatten(on: req)
    }

    private func makeItemDataArray(itemCategoryItemPairs: [(Item, CategoryItem)], req: Request) throws -> Future<[ItemData]> {
        return try itemCategoryItemPairs
            .map { try self.makeItemData(item: $0, categoryItem: $1, req: req) }
            .flatten(on: req)
    }

    private func makeItemData(item: Item, categoryItem: CategoryItem, req: Request) throws -> Future<ItemData> {
        return try categoryItem.modifiers.query(on: req)
            .count().map { $0 > 0 }
            .thenThrowing { try ItemData(item: item, categoryItem: categoryItem, isModifiable: $0) }
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
    struct CategoryQuery: Codable {
        let isRoot: Bool?
    }
}

private extension CategoryController {
    struct CategoryData: Content {
        var id: Category.ID
        var name: String
        var parentCategoryID: Category.ID?
        var isParentCategory: Bool
        var isConstructable: Bool
        
        init(category: Category, isParentCategory: Bool) throws {
            self.id = try category.requireID()
            self.name = category.name
            self.parentCategoryID = category.parentCategoryID
            self.isParentCategory = isParentCategory
            self.isConstructable = category.isConstructable
        }
    }

    struct ItemData: Content {
        let id: Item.ID
        let categoryItemID: CategoryItem.ID?
        let name: String
        let description: String?
        let price: Int?
        let isModifiable: Bool
        
        init(item: Item,
             categoryItem: CategoryItem,
             isModifiable: Bool) throws {
            self.id = try item.requireID()
            self.categoryItemID = try categoryItem.requireID()
            self.name = item.name
            self.description = categoryItem.description
            self.price = categoryItem.price
            self.isModifiable = isModifiable
        }
    }
}

private extension Array where Element == CategoryController.ItemData {
    var isAllPriced: Bool { return allSatisfy { $0.price != nil } }

    func sorted() -> [CategoryController.ItemData] {
        if isAllPriced { return sorted { $0.price! < $1.price! } }
        else { return sorted { $0.name < $1.name } }
    }
}
