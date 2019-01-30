import Vapor
import AWSSDKSwiftCore
import DynamoDB

extension DynamoDB {
	public func getItems(_ input: DynamoDB.GetItemInput, on eventLoop: EventLoop) -> Future<DynamoDB.GetItemOutput> {
		let promise = eventLoop.newPromise(DynamoDB.GetItemOutput.self)
		DispatchQueue.global().async {
			do { promise.succeed(result: try self.getItem(input)) }
			catch { promise.fail(error: error) }
		}
		return promise.futureResult
	}
	
	public func query(_ input: DynamoDB.QueryInput, on eventLoop: EventLoop) -> Future<DynamoDB.QueryOutput> {
		let promise = eventLoop.newPromise(DynamoDB.QueryOutput.self)
		DispatchQueue.global().async {
			do { promise.succeed(result: try self.query(input)) }
			catch { promise.fail(error: error) }
		}
		return promise.futureResult
	}
}
