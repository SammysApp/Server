import Vapor
import FluentPostgreSQL

struct CategoryData: Codable {
	let id: Category.ID
	let name: String
	let subcategories: [CategoryData]?
}

struct ItemData: Codable {
	let id: Item.ID
	let name: String
}

struct AddDefaultData: PostgreSQLMigration {
	static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
		do {
			return Future<Void>.andAll([
				create(try categoriesData(), on: conn),
				create(try itemsData(), on: conn)
			], eventLoop: conn.eventLoop)
		}
		catch { return conn.future(error: error) }
	}

	static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
		return .done(on: conn)
	}
	
	private static var baseFilesURL: URL {
		return URL(fileURLWithPath: DirectoryConfig.detect().workDir)
			.appendingPathComponent("Sources/App/Configuration")
	}
	
	// Add categories
	private static func categoriesData() throws -> [CategoryData] {
		let categoriesDataURL = baseFilesURL.appendingPathComponent("categories.json")
		return try JSONDecoder().decode([CategoryData].self, from: Data(contentsOf: categoriesDataURL))
	}

	private static func category(for categoryData: CategoryData, parentID: Category.ID?) -> Category {
		return Category(id: categoryData.id, name: categoryData.name, parentID: parentID)
	}

	private static func create(_ categoriesData: [CategoryData]?, parentID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
		guard let futures = categoriesData?
			.map({ create($0, parentID: parentID, on: conn) })
			else { return .done(on: conn) }
		return Future<Void>.andAll(futures, eventLoop: conn.eventLoop)
	}
	
	private static func create(_ categoryData: CategoryData, parentID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
		return category(for: categoryData, parentID: parentID).create(on: conn)
			.then { create(categoryData.subcategories, parentID: $0.id, on: conn) }
	}
	
	// Add items
	private static func itemsData() throws -> [ItemData] {
		let itemsDataURL = baseFilesURL.appendingPathComponent("items.json")
		return try JSONDecoder().decode([ItemData].self, from: Data(contentsOf: itemsDataURL))
	}
	
	private static func item(for itemData: ItemData) -> Item {
		return Item(id: itemData.id, name: itemData.name)
	}
	
	private static func create(_ itemsData: [ItemData], on conn: PostgreSQLConnection) -> Future<Void> {
		return Future<Void>.andAll(
			itemsData.map { item(for: $0).create(on: conn).transform(to: ()) },
			eventLoop: conn.eventLoop
		)
	}
}
