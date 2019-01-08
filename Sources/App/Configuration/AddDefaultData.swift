import Vapor
import FluentPostgreSQL

class CategoryData: Codable {
	let id: Category.ID
	let name: String
	let subcategories: [CategoryData]?
}

struct AddDefaultData: PostgreSQLMigration {
	static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
		do { return create(try categoriesData(), on: conn) }
		catch { return conn.future(error: error) }
	}

	static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
		return .done(on: conn)
	}

	private static func categoriesData() throws -> [CategoryData] {
		let categoriesDataURL = URL(fileURLWithPath: DirectoryConfig.detect().workDir)
			.appendingPathComponent("Sources/App/Configuration", isDirectory: true)
			.appendingPathComponent("categories.json", isDirectory: false)
		return try JSONDecoder().decode([CategoryData].self, from: Data(contentsOf: categoriesDataURL))
	}

	private static func category(for categoryData: CategoryData, parentID: Category.ID?) -> Category {
		return Category(id: categoryData.id, name: categoryData.name, parentID: parentID)
	}

	private static func create(_ categoriesData: [CategoryData]?, parentID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
		guard let firstCategoryData = categoriesData?.first
			else { return .done(on: conn) }
		var future = create(firstCategoryData, parentID: parentID, on: conn)
		categoriesData?.dropFirst().forEach { category in
			future = future.then { create(category, parentID: parentID, on: conn) }
		}
		return future
	}
	
	private static func create(_ categoryData: CategoryData, parentID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
		return category(for: categoryData, parentID: parentID).create(on: conn)
			.then { create(categoryData.subcategories, parentID: $0.id, on: conn) }
	}
}
