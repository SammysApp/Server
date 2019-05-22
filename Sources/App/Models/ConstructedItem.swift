import Vapor
import FluentPostgreSQL

final class ConstructedItem: PostgreSQLUUIDModel {
    var id: ConstructedItem.ID?
    var categoryID: Category.ID
    var userID: User.ID?
    var name: String?
    var isFavorite: Bool
    
    init(id: ConstructedItem.ID? = nil,
         categoryID: Category.ID,
         userID: User.ID? = nil,
         name: String? = nil,
         isFavorite: Bool = false) {
        self.id = id
        self.categoryID = categoryID
        self.userID = userID
        self.name = name
        self.isFavorite = isFavorite
    }
}

extension ConstructedItem: Parameter {}
extension ConstructedItem: Content {}
extension ConstructedItem: Migration {}

extension ConstructedItem {
    var category: Parent<ConstructedItem, Category> {
        return parent(\.categoryID)
    }
}

extension ConstructedItem {
    var categoryItems: Siblings<ConstructedItem, CategoryItem, ConstructedItemCategoryItem> { return siblings() }
}

extension ConstructedItem {
    var modifiers: Siblings<ConstructedItem, Modifier, ConstructedItemModifier> { return siblings() }
}

extension ConstructedItem {
    func name(on conn: DatabaseConnectable) throws -> Future<String> {
        if let name = name { return conn.future(name) }
        return category.get(on: conn).map { return $0.name }
    }
    
    func description(on conn: DatabaseConnectable) throws -> Future<String> {
        return try categoryItems.query(on: conn).join(\Item.id, to: \CategoryItem.itemID).alsoDecode(Item.self).all().flatMap { pairs -> Future<[String]> in
            var itemDescriptions = [String]()
            return try pairs.map { categoryItem, item in
                var itemDescription = item.name
                return try self.modifiers.query(on: conn).filter(\.categoryItemID == categoryItem.requireID()).all().do { modifiers in
                    if !modifiers.isEmpty {
                        itemDescription += " (" + modifiers.map { $0.name }.joined(separator: ", ") + ")"
                    }
                }.transform(to: itemDescription)
                    .do { itemDescriptions.append($0) }.transform(to: ())
            }.flatten(on: conn).transform(to: itemDescriptions)
        }.map { $0.joined(separator: ", ") }
    }
}

extension ConstructedItem {
    func totalPrice(on conn: DatabaseConnectable) throws -> Future<Int> {
        return try categoryItems.query(on: conn).all().map { $0 as [Purchasable] }
            .and(modifiers.query(on: conn).all().map { $0 as [Purchasable] })
            .map { ($0 + $1).totalPrice }
    }
}
