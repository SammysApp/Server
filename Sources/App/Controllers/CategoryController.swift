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
		let mongoClient = try req.make(MongoClient.self)
		return try req.parameters.next(Category.self)
			.flatMap { try $0.items.query(on: req).all().and(result: $0) }
			.map { items, category in
				try items.map { try GetItem(item: $0, itemDoc: self.itemDoc(for: $0, in: category, client: mongoClient)) }
			}
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
	
	// MongoDB methods
	func mongoDatabase(_ client: MongoClient) throws -> MongoDatabase {
		return try client.db(AppConstants.MongoDB.database)
	}
	
	func itemsCollection(_ client: MongoClient) throws -> MongoCollection<ItemDocument> {
		return try mongoDatabase(client).collection(AppConstants.MongoDB.itemsCollection, withType: ItemDocument.self)
	}
	
	func itemDoc(for item: Item, in category: Category, client: MongoClient) throws -> ItemDocument? {
		return try itemsCollection(client).find([
			ItemDocument.CodingKeys.category.rawValue: category.asBinary(),
			ItemDocument.CodingKeys.item.rawValue: item.asBinary()
		]).next()
	}
}
