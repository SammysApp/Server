import Vapor

protocol CategorizableCategory: Equatable {}
protocol CategorizableItem {}

struct CategoryItemsCategorizer {
    func makeCategorizedItems<C: CategorizableCategory, I: CategorizableItem>(pairs: [(C, I)]) -> [CategorizedItems<C, I>] {
        var categorizedItems = [CategorizedItems<C, I>]()
        var currentCategory: C?
        var currentItems = [I]()
        for (category, item) in pairs {
            if currentCategory != category {
                if let currentCategory = currentCategory {
                    categorizedItems.append(CategorizedItems<C, I>(category: currentCategory, items: currentItems))
                }
                currentCategory = category; currentItems = [item]
            } else { currentItems.append(item) }
        }
        if let currentCategory = currentCategory {
            categorizedItems.append(CategorizedItems<C, I>(category: currentCategory, items: currentItems))
        }
        return categorizedItems
    }
}

struct CategorizedItems<C: CategorizableCategory, I: CategorizableItem> {
    let category: C
    let items: [I]
}

extension Category: CategorizableCategory {}
extension Item: CategorizableItem {}

extension CategorizedItems: Codable where C: Codable, I: Codable {}
