import MongoSwift
import Vapor

struct CategoryItemDocument: Codable {
	var id: ObjectId?
	let category: Category.ID
	let item: Item.ID
	
	var modifiers: [Modifier]?
	
	init(id: ObjectId? = nil,
		 category: Category.ID,
		 item: Item.ID,
		 modifiers: [Modifier]? = nil) {
		self.id = id
		self.category = category
		self.item = item
		self.modifiers = modifiers
	}
	
	enum CodingKeys: String, CodingKey {
		case id = "_id"
		case category, item, modifiers
	}
	
	struct Modifier: Codable {
		let id: UUID
		let name: String
		let price: Double?
	}
}

extension CategoryItemDocument.Modifier: Content {}
