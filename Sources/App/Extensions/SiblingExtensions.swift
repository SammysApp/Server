import Vapor
import Fluent

extension Siblings
	where Through: ModifiablePivot, Through.Left == Base, Through.Right == Related, Through.Database: QuerySupporting {
	func attachAll(_ models: [Related], on conn: DatabaseConnectable) -> Future<Void> {
		return Future<Void>.andAll(
			models.map { attach($0, on: conn).transform(to: ()) },
			eventLoop: conn.eventLoop
		)
	}
}
