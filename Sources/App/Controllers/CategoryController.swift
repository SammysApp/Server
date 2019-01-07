import Vapor

final class CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoryRoute = router.grouped("categories")
		
		categoryRoute.get(use: allCategories)
		categoryRoute.get(Category.parameter, "subcategories", use: allSubcategories)
		
		categoryRoute.post(Category.self, use: save)
	}
	
	func allCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).all()
	}
	
	func allSubcategories(_ req: Request) throws -> Future<[Category]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.subcategories.query(on: req).all() }
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
}
