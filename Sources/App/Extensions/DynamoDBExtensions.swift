import Vapor
import AWSSDKSwiftCore
import DynamoDB

extension DynamoDB {
	func getItems(_ input: DynamoDB.GetItemInput, on eventLoop: EventLoop) -> Future<DynamoDB.GetItemOutput> {
		let promise = eventLoop.newPromise(DynamoDB.GetItemOutput.self)
		DispatchQueue.global().async {
			do {
				let item = try self.getItem(input)
				promise.succeed(result: item)
			} catch { promise.fail(error: error) }
		}
		return promise.futureResult
	}
}
