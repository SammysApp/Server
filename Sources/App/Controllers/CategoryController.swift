import Vapor

final class CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoriesRoute = router.grouped("categories")
		
		categoriesRoute.get(use: allCategories)
		categoriesRoute.get(Category.parameter, "subcategories", use: allSubcategories)
		categoriesRoute.get(Category.parameter, "items", use: allItems)
		
		categoriesRoute.post(Category.self, use: save)
	}
	
	func allCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).all()
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
