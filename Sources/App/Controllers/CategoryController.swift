import Vapor
import Fluent
import FluentPostgreSQL
import AWSSDKSwiftCore
import DynamoDB

typealias Request = Vapor.Request

final class CategoryController {
	private let dynamoDB = DynamoDB(
		accessKeyId: AppSecrets.AWS.accessKeyId,
		secretAccessKey: AppSecrets.AWS.secretAccessKey
	)
	
	func allCategories(_ req: Request) -> Future<[CategoryResponse]> {
		var databaseQuery = Category.query(on: req)
		if let requestQuery = try? req.query.decode(CategoryRequestQuery.self) {
			if let isRoot = requestQuery.isRoot, isRoot {
				databaseQuery = databaseQuery.filter(\.parentCategoryID == nil)
			}
		}
		return databaseQuery.all()
			.flatMap { try self.categoryResponses(req, categories: $0) }
	}
	
	func allSubcategories(_ req: Request) throws -> Future<[CategoryResponse]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.subcategories.query(on: req).all() }
			.flatMap { try self.categoryResponses(req, categories: $0) }
	}
	
	func categoryResponses(_ req: Request, categories: [Category]) throws
		-> Future<[CategoryResponse]> {
		return try categories.map { category in
			try category.subcategories.query(on: req)
				.count().map { $0 > 0 }.thenThrowing
				{ try CategoryResponse(category: category, isParentCategory: $0) }
		}.flatten(on: req)
	}
	
	func allCategoryRules(_ req: Request) throws -> Future<CategoryRulesResponse> {
		return try req.parameters.next(Category.self)
			.flatMap { try self.dynamoDB.getItems(.init(
				key: ["category": $0.asAttributeValue() ],
				tableName: String(describing: Category.self),
				attributesToGet: ["rules"]), on: req.eventLoop)
			}.map { CategoryRulesResponse(from: $0.item?["rules"]?.m ?? [:]) }
	}
	
	func allItems(_ req: Request) throws -> Future<[ItemResponse]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.items.query(on: req).alsoDecode(CategoryItem.self).all() }
			.flatMap { itemCategoryItemPairs in
				try itemCategoryItemPairs.map { pair -> Future<ItemResponse> in
					let (item, categoryItem) = pair
					return try categoryItem.modifiers.query(on: req)
						.count().map { $0 > 0 }
						.thenThrowing { isModifiable -> ItemResponse in
							try ItemResponse(item: item, categoryItem: categoryItem, isModifiable: isModifiable) }
				}.flatten(on: req)
			}.map { $0.sorted() }
	}
	
	func allCategoryItemModifiers(_ req: Request) throws -> Future<[ModifierResponse]> {
		return try req.parameters.next(Category.self)
			.and(try req.parameters.next(Item.self))
			.flatMap { try $0.pivot(attaching: $1, on: req)
				.unwrap(or: Abort(.badRequest))
				.flatMap { try $0.modifiers.query(on: req).all() }
				.map { try $0.map(ModifierResponse.init) } }
	}
	
	func allCategoryItemRules(_ req: Request) throws -> Future<CategoryItemRulesResponse> {
		return try req.parameters.next(Category.self)
			.and(try req.parameters.next(Item.self))
			.flatMap { try self.dynamoDB.getItems(.init(
				key: ["category": $0.asAttributeValue(), "item": $1.asAttributeValue()],
				tableName: String(describing: CategoryItem.self)), on: req.eventLoop)
			}.map { CategoryItemRulesResponse(from: $0.item?["rules"]?.m ?? [:]) }
	}
	
	func allConstructedItems(_ req: Request) throws
		-> Future<[ConstructedItemResponse]> {
		return try req.parameters.next(Category.self)
			.flatMap { try $0.constructedItems.query(on: req).all() }
			.flatMap { constructedItems in try constructedItems.map { try self.responseContent(for: $0, conn: req) }.flatten(on: req) }
	}
	
	func save(_ req: Request, category: Category) -> Future<Category> {
		return category.save(on: req)
	}
	
	func save(_ req: Request, content: ConstructedItemRequest) throws
		-> Future<ConstructedItemResponse> {
		return try req.parameters.next(Category.self)
			.then { ConstructedItem(id: content.id, parentCategoryID: $0.id)
				.save(on: req) }
			.and(CategoryItem.query(on: req).filter(\.id ~~ content.items).all())
			.then { $0.categoryItems.attachAll($1, on: req).transform(to: $0) }
			.and(Modifier.query(on: req).filter(\.id ~~ (content.modifiers ?? [])).all())
			.then { $0.modifiers.attachAll($1, on: req).transform(to: $0) }
			.flatMap { try self.responseContent(for: $0, conn: req) }
	}
	
	func responseContent(for constructedItem: ConstructedItem, conn: DatabaseConnectable) throws -> Future<ConstructedItemResponse> {
		return try constructedItem.categoryItems.query(on: conn)
			.join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self)
			.join(\Category.id, to: \CategoryItem.categoryID).alsoDecode(Category.self)
			.all().flatMap { categoryItemTuples in
				try categoryItemTuples.map { tuple -> Future<(Category, ItemResponse)> in
					let ((categoryItem, item), category) = tuple
					return try constructedItem.modifiers.query(on: conn)
						.filter(\.parentCategoryItemID == categoryItem.id).all()
						.map { try (category, ItemResponse(item: item, categoryItem: categoryItem, modifiers: $0.map { try ModifierResponse($0) })) }
				}.flatten(on: conn)
			}.and(constructedItem.totalPrice(on: conn))
			.map { try ConstructedItemResponse(id: constructedItem.requireID(), price: $1, items: self.categorizedItems(from: $0)) }
	}
	
	func categorizedItems(from categoryItemPairs: [(Category, ItemResponse)]) -> [CategorizedItemsResponse] {
		var categorizedItems = [CategorizedItemsResponse]()
		var currentCategory: Category?
		var currentItems = [ItemResponse]()
		for (category, item) in categoryItemPairs {
			if currentCategory != category {
				if let currentCategory = currentCategory {
					categorizedItems.append(CategorizedItemsResponse(category: currentCategory, items: currentItems))
				}
				currentCategory = category; currentItems = [item]
			}
			else { currentItems.append(item) }
		}
		if let currentCategory = currentCategory {
			categorizedItems.append(CategorizedItemsResponse(category: currentCategory, items: currentItems))
		}
		return categorizedItems
	}
}

extension CategoryController: RouteCollection {
	func boot(router: Router) throws {
		let categoriesRoute = router.grouped("\(AppConstants.version)/categories")
		
		categoriesRoute.get(use: allCategories)
		
		categoriesRoute.get(Category.parameter, "rules", use: allCategoryRules)
		categoriesRoute.get(Category.parameter, "subcategories", use: allSubcategories)
		categoriesRoute.get(Category.parameter, "items", use: allItems)
		
		categoriesRoute.get(Category.parameter, "items", Item.parameter, "rules", use: allCategoryItemRules)
		categoriesRoute.get(Category.parameter, "items", Item.parameter, "modifiers", use: allCategoryItemModifiers)
		
		categoriesRoute.get(Category.parameter, "constructedItems", use: allConstructedItems)
		
		categoriesRoute.post(Category.self, use: save)
		categoriesRoute.post(ConstructedItemRequest.self, at: Category.parameter, "constructedItems", use: save)
	}
}

struct CategoryRequestQuery: Codable {
	let isRoot: Bool?
}

struct CategoryResponse: Content {
	var id: Category.ID
	var name: String
	var parentCategoryID: Category.ID?
	var isParentCategory: Bool
	var isConstructable: Bool
	
	init(category: Category, isParentCategory: Bool) throws {
		self.id = try category.requireID()
		self.name = category.name
		self.parentCategoryID = category.parentCategoryID
		self.isParentCategory = isParentCategory
		self.isConstructable = category.isConstructable
	}
}

struct ItemResponse: Content {
	let id: Item.ID
	let categoryItemID: CategoryItem.ID?
	let name: String
	let description: String?
	let price: Int?
	let modifers: [ModifierResponse]?
	let isModifiable: Bool?
	
	init(item: Item,
		 categoryItem: CategoryItem? = nil,
		 modifiers: [ModifierResponse]? = nil,
		 isModifiable: Bool? = nil) throws {
		self.id = try item.requireID()
		self.categoryItemID = try categoryItem?.requireID()
		self.name = item.name
		self.description = categoryItem?.description
		self.price = categoryItem?.price
		if let modifiers = modifiers {
			self.modifers = modifiers.isEmpty ? nil : modifiers
		} else { self.modifers = nil }
		self.isModifiable = isModifiable
	}
}

struct ModifierResponse: Content {
	let id: Modifier.ID
	let name: String
	let price: Int?
	
	init(_ modifier: Modifier) throws {
		self.id = try modifier.requireID()
		self.name = modifier.name
		self.price = modifier.price
	}
}

struct CategoryRulesResponse: Content {
	let maxItems: Int?
	
	init(from mapValue: [String: DynamoDB.AttributeValue]) {
		self.maxItems = mapValue[CategoryRulesResponse.CodingKeys.maxItems.stringValue]?.n?.asInt()
	}
}

struct CategoryItemRulesResponse: Content {
	let maxModifiers: Int?
	
	init(from mapValue: [String: DynamoDB.AttributeValue]) {
		self.maxModifiers = mapValue[CategoryItemRulesResponse.CodingKeys.maxModifiers.stringValue]?.n?.asInt()
	}
}

struct ConstructedItemRequest: Content {
	let id: ConstructedItem.ID?
	let items: [CategoryItem.ID]
	let modifiers: [Modifier.ID]?
}

struct ConstructedItemResponse: Content {
	let id: ConstructedItem.ID
	let price: Int
	let items: [CategorizedItemsResponse]
}

struct CategorizedItemsResponse: Content {
	let category: Category
	let items: [ItemResponse]
}

extension Array where Element == ItemResponse {
	var isAllPriced: Bool { return allSatisfy { $0.price != nil } }
	
	func sorted() -> [ItemResponse] {
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
