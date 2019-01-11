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
		categoriesRoute.post(Category.parameter, "items", Item.parameter, use: test)
	}
	
	func mongoClient(_ req: Request) throws -> MongoClient {
		return try req.make(MongoClient.self)
	}
	
	func mongoDatabase(_ req: Request) throws -> MongoDatabase {
		return try mongoClient(req).db(AppConstants.MongoDB.database)
	}
	
	func itemsCollection(_ req: Request) throws -> MongoCollection<ItemDocument> {
		return try mongoDatabase(req).collection(AppConstants.MongoDB.itemsCollection, withType: ItemDocument.self)
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
	
	func allItems(_ req: Request) throws -> Future<[Item]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.items.query(on: req).all() }
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
}
