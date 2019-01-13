import Foundation
import MongoSwift

struct ItemDocument: Codable {
	var id: ObjectId?
	let category: Category.ID
	let item: Item.ID
	
	init(id: ObjectId? = nil,
		 category: Category.ID,
		 item: Item.ID) {
		self.id = id
		self.category = category
		self.item = item
	}
	
	enum CodingKeys: String, CodingKey {
		case id = "_id"
		case category, item
	}
}
