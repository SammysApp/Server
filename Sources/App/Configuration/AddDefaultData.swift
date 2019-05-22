import Vapor
import FluentPostgreSQL

struct AddDefaultData {
    private struct Constants {
        static let baseFilesPath = "Sources/App/Configuration"
        static let storeHoursFileName = "StoreHours.json"
        static let itemsFileName = "Items.json"
        static let categoriesFileName = "Categories.json"
        static let categoryItemsFileName = "CategoryItems.json"
    }
    
    private static var baseFilesURL: URL {
        return URL(fileURLWithPath: DirectoryConfig.detect().workDir)
            .appendingPathComponent(Constants.baseFilesPath)
    }
    
    // MARK: - Store Hours
    private static func makeStoreHoursData() throws -> [StoreHoursData] {
        let storeHoursDataURL = baseFilesURL.appendingPathComponent(Constants.storeHoursFileName)
        return try JSONDecoder().decode([StoreHoursData].self, from: Data(contentsOf: storeHoursDataURL))
    }
    
    private static func makeStoreHours(storeHoursData: StoreHoursData) -> StoreHours {
        return StoreHours(
            weekday: storeHoursData.weekday,
            openingHour: storeHoursData.openingHour,
            openingMinute: storeHoursData.openingMinute,
            closingHour: storeHoursData.closingHour,
            closingMinute: storeHoursData.closingMinute,
            isOpen: storeHoursData.isOpen ?? true,
            isClosingNextDay: storeHoursData.isClosingNextDay ?? false
        )
    }
    
    private static func create(_ storeHoursData: [StoreHoursData], on conn: PostgreSQLConnection) -> Future<Void> {
        return storeHoursData.map { makeStoreHours(storeHoursData: $0).create(on: conn).transform(to: ()) }.flatten(on: conn)
    }
    
    // MARK: - Items
    private static func makeItemsData() throws -> [ItemData] {
        let itemsDataURL = baseFilesURL.appendingPathComponent(Constants.itemsFileName)
        return try JSONDecoder().decode([ItemData].self, from: Data(contentsOf: itemsDataURL))
    }
    
    private static func makeItem(itemData: ItemData) -> Item {
        return Item(id: itemData.id, name: itemData.name)
    }
    
    private static func create(_ itemsData: [ItemData], on conn: PostgreSQLConnection) -> Future<Void> {
        return itemsData.map { makeItem(itemData: $0).create(on: conn).transform(to: ()) }.flatten(on: conn)
    }
    
    // MARK: - Categories
    private static func makeCategoriesData() throws -> [CategoryData] {
        let categoriesDataURL = baseFilesURL.appendingPathComponent(Constants.categoriesFileName)
        return try JSONDecoder().decode([CategoryData].self, from: Data(contentsOf: categoriesDataURL))
    }
    
    private static let categoryItemsData: [CategoryItemData] = {
        let categoryItemsDataURL = baseFilesURL.appendingPathComponent(Constants.categoryItemsFileName)
        do { return try JSONDecoder().decode([CategoryItemData].self, from: Data(contentsOf: categoryItemsDataURL)) }
        catch { preconditionFailure(error.localizedDescription) }
    }()
    
    private static func makeCategory(categoryData: CategoryData, parentCategoryID: Category.ID?) -> Category {
        return Category(
            id: categoryData.id,
            parentCategoryID: parentCategoryID,
            name: categoryData.name,
            imageURL: categoryData.imageURL,
            minimumItems: categoryData.minimumItems,
            maximumItems: categoryData.maximumItems,
            isConstructable: categoryData.isConstructable ?? false
        )
    }
    
    private static func create(_ categoriesData: [CategoryData]?, parentCategoryID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
        guard let futures = categoriesData?
            .map({ create($0, parentCategoryID: parentCategoryID, on: conn) })
            else { return .done(on: conn) }
        return futures.flatten(on: conn)
    }
    
    private static func create(_ categoryData: CategoryData, parentCategoryID: Category.ID? = nil, on conn: PostgreSQLConnection) -> Future<Void> {
        return makeCategory(categoryData: categoryData, parentCategoryID: parentCategoryID).create(on: conn)
            .then { attach(categoryData.items, to: $0, on: conn).transform(to: $0) }
            .then { create(categoryData.subcategories, parentCategoryID: $0.id, on: conn) }
    }
    
    private static func attach(_ itemIDs: [Item.ID]?, to category: Category, on conn: PostgreSQLConnection) -> Future<Void> {
        guard let ids = itemIDs else { return .done(on: conn) }
        return ids.map { attach($0, to: category, on: conn) }.flatten(on: conn)
    }
    
    private static func attach(_ itemID: Item.ID, to category: Category, on conn: PostgreSQLConnection) -> Future<Void> {
        return Item.find(itemID, on: conn)
            .unwrap(or: AddDefaultDataError.cantFindItem)
            .then { category.items.attach($0, on: conn) }.flatMap { categoryItem in
                guard let categoryItemData = categoryItemsData.first(where: { $0.category == categoryItem.categoryID && $0.item == categoryItem.itemID })
                    else { return conn.future() }
                return try update(categoryItem, with: categoryItemData, on: conn)
                    .transform(to: ())
                    .flatMap { try create(categoryItemData.modifiers, with: categoryItem.requireID(), on: conn) }
            }
    }
    
    private static func update(_ categoryItem: CategoryItem, with data: CategoryItemData, on conn: PostgreSQLConnection) throws -> Future<CategoryItem> {
        categoryItem.description = data.description
        categoryItem.price = data.price
        categoryItem.minimumModifiers = data.minimumModifiers
        categoryItem.maximumModifiers = data.maximumModifiers
        return categoryItem.save(on: conn)
    }
    
    // MARK: - Modifiers
    private static func makeModifier(modifierData: ModifierData, categoryItemID: CategoryItem.ID) -> Modifier {
        return Modifier(
            categoryItemID: categoryItemID,
            name: modifierData.name,
            price: modifierData.price
        )
    }
    
    private static func create(_ modifiersData: [ModifierData]?, with categoryItemID: CategoryItem.ID, on conn: PostgreSQLConnection) -> Future<Void> {
        return (modifiersData?.map { makeModifier(modifierData: $0, categoryItemID: categoryItemID).create(on: conn).transform(to: ()) } ?? []).flatten(on: conn)
    }
}

extension AddDefaultData: PostgreSQLMigration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        do {
            return try [create(makeStoreHoursData(), on: conn),
                        create(makeItemsData(), on: conn),
                        create(makeCategoriesData(), on: conn)].flatten(on:  conn)
        }
        catch { return conn.future(error: error) }
    }
    
    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
        return .done(on: conn)
    }
}

private extension AddDefaultData {
    struct StoreHoursData: Codable {
        let weekday: Int
        let openingHour: Int?
        let openingMinute: Int?
        let closingHour: Int?
        let closingMinute: Int?
        let isOpen: Bool?
        let isClosingNextDay: Bool?
    }
    
    struct CategoryData: Codable {
        let id: Category.ID
        let name: String
        let imageURL: String?
        let minimumItems: Int?
        let maximumItems: Int?
        let isConstructable: Bool?
        let subcategories: [CategoryData]?
        let items: [Item.ID]?
    }
    
    struct ItemData: Codable {
        let id: Item.ID
        let name: String
    }
    
    struct CategoryItemData: Codable {
        let category: Category.ID
        let item: Item.ID
        let description: String?
        let price: Int?
        var minimumModifiers: Int?
        var maximumModifiers: Int?
        let modifiers: [ModifierData]?
    }
    
    struct ModifierData: Codable {
        let name: String
        let price: Int?
    }
}

enum AddDefaultDataError: Error {
    case cantFindItem
}
