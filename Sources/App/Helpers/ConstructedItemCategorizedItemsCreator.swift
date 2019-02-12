import Vapor
import Fluent
import FluentPostgreSQL

struct ConstructedItemCategorizedItemsCreator {
	typealias ConstructedItemCategorizedItems = CategorizedItems<CategoryData, ItemData>
	
	private let categorizer = CategoryItemsCategorizer()
	
	func create(for constructedItem: ConstructedItem, on conn: DatabaseConnectable)
		throws -> Future<[ConstructedItemCategorizedItems]> {
		return try constructedItem.categoryItems.query(on: conn)
			.join(\Category.id, to: \CategoryItem.categoryID).alsoDecode(Category.self)
			.join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self).all()
			.flatMap { try $0.map { tuple -> Future<(CategoryData, ItemData)> in
				let ((categoryItem, category), item) = tuple
				return try constructedItem.modifiers.query(on: conn)
					.filter(\.parentCategoryItemID == categoryItem.id).all()
					.map { try $0.map { try ModifierData($0) } }
					.map { try (CategoryData(category), ItemData(item: item, categoryItem: categoryItem, modifiers: ($0.isEmpty ? nil : $0))) }
			}.flatten(on: conn) }.map { self.categorizer.categorizedItems(from: $0) }
	}
}

extension ConstructedItemCategorizedItemsCreator {
	struct CategoryData: Content, CategorizableCategory {
		let id: Category.ID
		let name: String
		
		init(_ category: Category) throws {
			self.id = try category.requireID()
			self.name = category.name
		}
	}
	
	struct ItemData: Content, CategorizableItem {
		let id: Item.ID
		let name: String
		let description: String?
		let price: Int?
		let modifiers: [ModifierData]?
		
		init(item: Item,
			 categoryItem: CategoryItem,
			 modifiers: [ModifierData]? = nil) throws {
			self.id = try item.requireID()
			self.name = item.name
			self.description = categoryItem.description
			self.price = categoryItem.price
			self.modifiers = modifiers
		}
	}
	
	struct ModifierData: Content {
		let id: Modifier.ID
		let name: String
		let price: Int?
		
		init(_ modifier: Modifier) throws {
			self.id = try modifier.requireID()
			self.name = modifier.name
			self.price = modifier.price
		}
	}
}
