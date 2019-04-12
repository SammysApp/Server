import Vapor
import FluentPostgreSQL

final class Category: PostgreSQLUUIDModel {
    var id: Category.ID?
    var parentCategoryID: Category.ID?
    var name: String
    var imageURL: String?
    var minimumItems: Int?
    var maximumItems: Int?
    var isConstructable: Bool
    var availability: Availability
    
    init(id: Category.ID? = nil,
         parentCategoryID: Category.ID? = nil,
         name: String,
         imageURL: String? = nil,
         minimumItems: Int? = nil,
         maximumItems: Int? = nil,
         isConstructable: Bool = false,
         availability: Availability = .isAvailable) {
        self.id = id
        self.parentCategoryID = parentCategoryID
        self.name = name
        self.imageURL = imageURL
        self.minimumItems = minimumItems
        self.maximumItems = maximumItems
        self.isConstructable = isConstructable
        self.availability = availability
    }
}

extension Category: Content {}
extension Category: Parameter {}
extension Category: Migration {}

extension Category: Equatable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        do { return try lhs.requireID() == rhs.requireID() } catch { return false }
    }
}

extension Category {
    var parentCategory: Parent<Category, Category>? {
        return parent(\.parentCategoryID)
    }
    
    var subcategories: Children<Category, Category> {
        return children(\.parentCategoryID)
    }
}

extension Category {
    var items: Siblings<Category, Item, CategoryItem> { return siblings() }
}

extension Category {
    var constructedItems: Children<Category, ConstructedItem> {
        return children(\.categoryID)
    }
}

extension Category {
    func pivot(attaching item: Item, on conn: DatabaseConnectable) throws -> Future<CategoryItem?> {
        return try items.pivots(on: conn)
            .filter(\.categoryID == requireID())
            .filter(\.itemID == item.requireID())
            .first()
    }
}
