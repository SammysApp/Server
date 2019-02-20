import Vapor
import Fluent
import FluentPostgreSQL

typealias ConstructedItemCategorizedItems = CategorizedItems<ConstructedItemCategorizedCategoryData, ConstructedItemCategorizedItemData>

struct ConstructedItemCategorizedItemsCreator {
    private let categorizer = CategoryItemsCategorizer()
    
    func create(for constructedItem: ConstructedItem, on conn: DatabaseConnectable) throws -> Future<[ConstructedItemCategorizedItems]> {
        return try constructedItem.categoryItems.query(on: conn)
            .join(\Category.id, to: \CategoryItem.categoryID).alsoDecode(Category.self)
            .join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self).all()
            .flatMap { try $0.map { tuple -> Future<(ConstructedItemCategorizedCategoryData, ConstructedItemCategorizedItemData)> in
                let ((categoryItem, category), item) = tuple
                return try constructedItem.modifiers.query(on: conn)
                    .filter(\.parentCategoryItemID == categoryItem.id).all()
                    .map { try $0.map { try ConstructedItemCategorizedModifierData($0) } }
                    .map { try (ConstructedItemCategorizedCategoryData(category), ConstructedItemCategorizedItemData(item: item, categoryItem: categoryItem, modifiers: ($0.isEmpty ? nil : $0))) }
                }.flatten(on: conn) }.map { self.categorizer.makeCategorizedItems(pairs: $0) }
    }
}

struct ConstructedItemCategorizedCategoryData: Content, CategorizableCategory {
    let id: Category.ID
    let name: String
    
    init(_ category: Category) throws {
        self.id = try category.requireID()
        self.name = category.name
    }
}

struct ConstructedItemCategorizedItemData: Content, CategorizableItem {
    let id: Item.ID
    let name: String
    let description: String?
    let price: Int?
    let modifiers: [ConstructedItemCategorizedModifierData]?
    
    init(item: Item,
         categoryItem: CategoryItem,
         modifiers: [ConstructedItemCategorizedModifierData]? = nil) throws {
        self.id = try item.requireID()
        self.name = item.name
        self.description = categoryItem.description
        self.price = categoryItem.price
        self.modifiers = modifiers
    }
}

struct ConstructedItemCategorizedModifierData: Content {
    let id: Modifier.ID
    let name: String
    let price: Int?
    
    init(_ modifier: Modifier) throws {
        self.id = try modifier.requireID()
        self.name = modifier.name
        self.price = modifier.price
    }
}
