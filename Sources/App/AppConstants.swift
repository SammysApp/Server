import Foundation

struct AppConstants {
	static let version = "v1"
	
	struct PostgreSQL {
		struct Local {
			static let hostname = "localhost"
			static let port = 5432
			static let username = "natanel"
			static let database = "sammys"
		}
		
		struct AWS {
			static let hostname = "sammys.cqd1sjetbcgb.us-east-1.rds.amazonaws.com"
			static let port = 5432
			static let username = "niazoff"
			static let database = "dev"
		}
	}
}
