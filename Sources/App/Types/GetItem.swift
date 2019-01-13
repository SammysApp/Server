import Vapor

struct GetItem: Content {
	let id: Item.ID
	let name: String
	let price: Double?
	
	init(item: Item, itemDoc: ItemDocument?) throws {
		self.id = try item.requireID()
		self.name = item.name
		self.price = itemDoc?.price
	}
}
