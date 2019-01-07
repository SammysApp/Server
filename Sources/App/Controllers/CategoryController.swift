import Vapor

final class CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoryRoute = router.grouped("categories")
		
		categoryRoute.get(use: allCategories)
		categoryRoute.get(UUID.parameter, "subcategories", use: allSubcategories)
		
		categoryRoute.post(Category.self, use: save)
	}
	
	func allCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).all()
	}
	
	func allSubcategories(_ req: Request) throws -> Future<[Category]> {
		return Category.find(try req.parameters.next(UUID.self), on: req).flatMap {
			guard let category = $0 else { throw Abort(.badRequest) }
			return try category.subcategories.query(on: req).all()
		}
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
}
