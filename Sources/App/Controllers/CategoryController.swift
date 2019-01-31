import Vapor
import Fluent
import FluentPostgreSQL
import AWSSDKSwiftCore
import DynamoDB

typealias Request = Vapor.Request

final class CategoryController {
	let dynamoDB = DynamoDB(
		accessKeyId: AppSecrets.AWS.accessKeyId,
		secretAccessKey: AppSecrets.AWS.secretAccessKey
	)
	
	func allCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).all()
	}
	
	func allRootCategories(_ req: Request) -> Future<[Category]> {
		return Category.query(on: req).filter(\.parentCategoryID == nil).all()
	}
	
	func allSubcategories(_ req: Request) throws -> Future<[Category]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.subcategories.query(on: req).all() }
	}
	
	func allCategoryRules(_ req: Request) throws -> Future<GetCategoryRules> {
		return try req.parameters.next(Category.self)
			.flatMap { try self.dynamoDB.getItems(.init(
				key: ["category": $0.asAttributeValue() ],
				tableName: String(describing: Category.self),
				attributesToGet: ["rules"]), on: req.eventLoop)
			}.map { GetCategoryRules(from: $0.item?["rules"]?.m ?? [:]) }
	}
	
	func allItems(_ req: Request) throws -> Future<[GetItem]> {
		return try req.parameters.next(Category.self).map { $0.items }
			.flatMap { try $0.query(on: req).all().and($0.pivots(on: req).all()) }
			.map { try self.getItems(items: $0, categoryItems: $1).sorted() }
	}
	
	func getItems(items: [Item], categoryItems: [CategoryItem]) throws -> [GetItem] {
		return try items.map { item in try GetItem(item: item, categoryItem: categoryItems.first { $0.itemID == item.id }) }
	}
	
	func allCategoryItemModifiers(_ req: Request) throws -> Future<[GetModifier]> {
		return try req.parameters.next(Category.self)
			.and(try req.parameters.next(Item.self))
			.flatMap { try $0.pivot(attaching: $1, on: req)
				.unwrap(or: Abort(.badRequest))
				.flatMap { try $0.modifiers.query(on: req).all() }
				.map { try $0.map(GetModifier.init) } }
	}
	
	func allCategoryItemRules(_ req: Request) throws -> Future<GetCategoryItemRules> {
		return try req.parameters.next(Category.self)
			.and(try req.parameters.next(Item.self))
			.flatMap { try self.dynamoDB.getItems(.init(
				key: ["category": $0.asAttributeValue(), "item": $1.asAttributeValue()],
				tableName: String(describing: CategoryItem.self)), on: req.eventLoop)
			}.map { GetCategoryItemRules(from: $0.item?["rules"]?.m ?? [:]) }
	}
	
	func allConstructedItems(_ req: Request) throws
		-> Future<[ConstructedItemResponse]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.constructedItems.query(on: req).all() }
			.flatMap { constructedItems in try constructedItems.map { try self.responseContent(for: $0, on: req) }.flatten(on: req) }
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
	
	func save(_ req: Request, content: ConstructedItemRequest) throws
		-> Future<ConstructedItemResponse> {
		return try req.parameters.next(Category.self)
			.then { ConstructedItem(id: content.id, parentCategoryID: $0.id)
				.save(on: req) }
			.and(CategoryItem.query(on: req).filter(\.id ~~ content.categoryItems).all())
			.then { $0.categoryItems.attachAll($1, on: req).transform(to: $0) }
			.flatMap { try self.responseContent(for: $0, on: req) }
	}
	
	func responseContent(for constructedItem: ConstructedItem, on conn: DatabaseConnectable) throws -> Future<ConstructedItemResponse> {
		return try constructedItem.categoryItems.query(on: conn).all()
			.flatMap { return self.categorizedItems(for: $0, on: conn) }
			.map { try ConstructedItemResponse(id: constructedItem.requireID(), items: $0) }
	}
	
	func categorizedItems(for categoryItems: [CategoryItem], on conn: DatabaseConnectable)
		-> Future<[CategorizedItems]> {
		return categoryItems.map {
			$0.category(on: conn).unwrap(or: Abort(.notFound))
			.and($0.item(on: conn).unwrap(or: Abort(.notFound)))
		}.flatten(on: conn).map { self.categorizedItems(from: $0) }
	}
	
	func categorizedItems(from categoryItemPairs: [(Category, Item)])
		-> [CategorizedItems] {
			var categorizedItems = [CategorizedItems]()
			var currentCategory: Category?
			var currentItems = [Item]()
			for (category, item) in categoryItemPairs {
				if currentCategory != category {
					if let currentCategory = currentCategory { categorizedItems.append(CategorizedItems(category: currentCategory, items: currentItems)) }
					currentCategory = category
					currentItems = [item]
				} else { currentItems.append(item) }
			}
			if let currentCategory = currentCategory { categorizedItems.append(CategorizedItems(category: currentCategory, items: currentItems)) }
			return categorizedItems
	}
}

extension CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoriesRoute = router.grouped("\(AppConstants.version)/categories")
		
		categoriesRoute.get(use: allCategories)
		categoriesRoute.get("roots", use: allRootCategories)
		
		categoriesRoute.get(Category.parameter, "rules", use: allCategoryRules)
		categoriesRoute.get(Category.parameter, "subcategories", use: allSubcategories)
		categoriesRoute.get(Category.parameter, "items", use: allItems)
		
		categoriesRoute.get(Category.parameter, "items", Item.parameter, "rules", use: allCategoryItemRules)
		categoriesRoute.get(Category.parameter, "items", Item.parameter, "modifiers", use: allCategoryItemModifiers)
		
		categoriesRoute.get(Category.parameter, "constructed-items", use: allConstructedItems)
		
		categoriesRoute.post(Category.self, use: save)
		categoriesRoute.post(ConstructedItemRequest.self, at: Category.parameter, "constructed-items", use: save)
	}
}

struct GetItem: Content {
	let id: Item.ID
	let name: String
	let description: String?
	let price: Decimal?
	
	init(item: Item, categoryItem: CategoryItem? = nil) throws {
		self.id = try item.requireID()
		self.name = item.name
		self.description = categoryItem?.description
		self.price = categoryItem?.price?.asDecimal()
	}
}

struct GetModifier: Content {
	let id: Modifier.ID
	let name: String
	let price: Decimal?
	
	init(_ modifier: Modifier) throws {
		self.id = try modifier.requireID()
		self.name = modifier.name
		self.price = modifier.price?.asDecimal()
	}
}

struct GetCategoryRules: Content {
	let maxItems: Int?
	
	init(from mapValue: [String: DynamoDB.AttributeValue]) {
		self.maxItems = mapValue[GetCategoryRules.CodingKeys.maxItems.stringValue]?.n?.asInt()
	}
}

struct GetCategoryItemRules: Content {
	let maxModifiers: Int?
	
	init(from mapValue: [String: DynamoDB.AttributeValue]) {
		self.maxModifiers = mapValue[GetCategoryItemRules.CodingKeys.maxModifiers.stringValue]?.n?.asInt()
	}
}

struct ConstructedItemRequest: Content {
	let id: ConstructedItem.ID?
	let categoryItems: [CategoryItem.ID]
}

struct ConstructedItemResponse: Content {
	let id: ConstructedItem.ID
	var items: [CategorizedItems]
}

struct CategorizedItems: Codable {
	let category: Category
	let items: [Item]
}

extension Array where Element == GetItem {
	var isAllPriced: Bool { return allSatisfy { $0.price != nil } }
	
	func sorted() -> [GetItem] {
		if isAllPriced { return sorted { $0.price! < $1.price! } }
		else { return sorted { $0.name < $1.name } }
	}
}

extension Model where ID == UUID {
	func asAttributeValue() throws -> DynamoDB.AttributeValue {
		return try .init(s: requireID().uuidString.lowercased())
	}
}

private extension String {
	func asInt() -> Int? { return Int(self) }
}

private extension Double {
	func asDecimal() -> Decimal { return Decimal(self) }
}
