import MongoKitten

protocol CollectionName { var name: String { get } }

extension RawRepresentable where Self: CollectionName, RawValue == String {
	var name: String { return rawValue }
}

extension Database {
	subscript(name: CollectionName) -> MongoKitten.Collection { return self[name.name] }
}
