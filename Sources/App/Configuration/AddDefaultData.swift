import Vapor
import FluentPostgreSQL

struct ItemData: Codable {
	let id: Item.ID
	let name: String
}

struct CategoryData: Codable {
	let id: Category.ID
	let name: String
	let items: [Item.ID]?
	let subcategories: [CategoryData]?
}

struct CategoryItemData: Codable {
	let category: Category.ID
	let item: Item.ID
	let description: String?
	let price: Double?
}

struct AddDefaultData: PostgreSQLMigration {
	static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
		do {
			return Future<Void>.andAll([
				create(try itemsData(), on: conn),
				create(try categoriesData(), on: conn)
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
	
	// Add items.
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
	
	// Add categories.
	private static func categoriesData() throws -> [CategoryData] {
		let categoriesDataURL = baseFilesURL.appendingPathComponent("categories.json")
		return try JSONDecoder().decode([CategoryData].self, from: Data(contentsOf: categoriesDataURL))
	}
	
	private static let categoryItemsData: [CategoryItemData] = {
		let categoryItemsDataURL = baseFilesURL.appendingPathComponent("category_items.json")
		return (try? JSONDecoder().decode([CategoryItemData].self, from: Data(contentsOf: categoryItemsDataURL))) ?? []
	}()
	
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
			.then { attach(categoryData.items, to: $0, on: conn).transform(to: $0) }
			.then { create(categoryData.subcategories, parentID: $0.id, on: conn) }
	}
	
	private static func attach(_ itemIDs: [Item.ID]?, to category: Category, on conn: PostgreSQLConnection) -> Future<Void> {
		guard let ids = itemIDs else { return .done(on: conn) }
		return Future<Void>.andAll(
			ids.map { attach($0, to: category, on: conn).transform(to: ()) },
			eventLoop: conn.eventLoop
		)
	}
	
	private static func attach(_ itemID: Item.ID, to category: Category, on conn: PostgreSQLConnection) -> Future<CategoryItem> {
		return Item.find(itemID, on: conn)
			.unwrap(or: AddDefaultDataError.cantFindItem)
			.then { category.items.attach($0, on: conn) }
			.flatMap { categoryItem in
				guard let categoryItemData = categoryItemsData.first(where: { $0.category == categoryItem.categoryID && $0.item == categoryItem.itemID }) else { return conn.future(categoryItem) }
				return try update(categoryItem, with: categoryItemData, on: conn)
			}
	}
	
	private static func update(_ categoryItem: CategoryItem, with data: CategoryItemData, on conn: PostgreSQLConnection) throws -> Future<CategoryItem> {
		categoryItem.description = data.description
		categoryItem.price = data.price
		return categoryItem.save(on: conn)
	}
}

enum AddDefaultDataError: Error {
	case cantFindItem
}
