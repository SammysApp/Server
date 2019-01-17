import Vapor
import FluentPostgreSQL
import MongoSwift

final class CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoriesRoute = router.grouped("\(AppConstants.version)/categories")
		
		categoriesRoute.get(use: allCategories)
		categoriesRoute.get("roots", use: allRootCategories)
		categoriesRoute.get(Category.parameter, "subcategories", use: allSubcategories)
		categoriesRoute.get(Category.parameter, "items", use: allItems)
		categoriesRoute.get(Category.parameter, "items", Item.parameter, "modifiers", use: allModifiers)
		
		categoriesRoute.post(Category.self, use: save)
	}
	
	func allCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).all()
	}
	
	func allRootCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).filter(\.parentID == nil).all()
	}
	
	func allSubcategories(_ req: Request) throws -> Future<[Category]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.subcategories.query(on: req).all() }
	}
	
	func allItems(_ req: Request) throws -> Future<[GetItem]> {
		return try req.parameters.next(Category.self).map { $0.items }
			.flatMap { try $0.query(on: req).all().and($0.pivots(on: req).all()) }
			.map { try self.createGetItems(from: $0, categoryItems: $1).sorted() }
	}
	
	func createGetItems(from items: [Item], categoryItems: [CategoryItem]) throws -> [GetItem] {
		return try items.map { item in try self.createGetItem(from: item, categoryItem: categoryItems.first { $0.itemID == item.id }) }
	}
	
	func createGetItem(from item: Item, categoryItem: CategoryItem? = nil) throws -> GetItem {
		return GetItem(id: try item.requireID(), name: item.name, description: categoryItem?.description, price: categoryItem?.price)
	}
	
	func allModifiers(_ req: Request) throws -> Future<[CategoryItemDocument.Modifier]> {
		let collection = try req.make(MongoClient.self).db(AppConstants.MongoDB.database)
			.collection(AppConstants.MongoDB.categoryItemsCollection, withType: CategoryItemDocument.self)
		return try req.parameters.next(Category.self)
			.and(req.parameters.next(Item.self))
			.map {
				let doc: Document = try [CategoryItemDocument.CodingKeys.category.rawValue: $0.asBinary(), CategoryItemDocument.CodingKeys.item.rawValue: $1.asBinary()]
				return try collection.find(doc).next()?.modifiers ?? []
			}
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
}

struct GetItem: Content {
	let id: Item.ID
	let name: String
	let description: String?
	let price: Double?
}

extension Array where Element == GetItem {
	var isAllPriced: Bool { return allSatisfy { $0.price != nil } }
	
	func sorted() -> [GetItem] {
		if isAllPriced { return sorted { $0.price! < $1.price! } }
		else { return sorted { $0.name < $1.name } }
	}
}
