import Foundation

struct AppConstants {
	static let version = "v1"
	
	struct PostgreSQL {
		static let hostname = "niazoff.cqd1sjetbcgb.us-east-1.rds.amazonaws.com"
		static let port = 5432
		static let username = "niazoff"
		static let database = "sammysserver"
	}
	
	struct MongoDB {
		static let connectionString = "mongodb+srv://natanel:\(AppSecrets.MongoDB.password)@cluster0-n8uy4.mongodb.net/test?retryWrites=true"
		static let database = "sammysserver"
		static let metadataCollection = "metadata"
		static let categoryItemsCollection = "category_items"
	}
}
