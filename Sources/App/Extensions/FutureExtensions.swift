import Vapor

extension Future {
    func `guard`(_ callback: @escaping ((Expectation) -> Bool), else error: Error) -> Future<T> {
        let promise = eventLoop.newPromise(T.self)
        self.do {
            if callback($0) { promise.succeed(result: $0) }
            else { promise.fail(error: error) }
            }.catch { promise.fail(error: $0) }
        return promise.futureResult
    }
}
