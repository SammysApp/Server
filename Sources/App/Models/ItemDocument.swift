import Vapor
import MongoSwift

struct ItemDocument: Codable {
	var id: ObjectId?
	let category: Category.ID
	let item: Item.ID
	
	var price: Double?
	
	init(id: ObjectId? = nil, category: Category.ID, item: Item.ID, price: Double? = nil) {
		self.id = id
		self.category = category
		self.item = item
		self.price = price
	}
	
	enum CodingKeys: String, CodingKey {
		case id = "_id"
		case category, item
		case price
	}
}

extension ItemDocument: Content {}
