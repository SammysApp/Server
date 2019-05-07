import Vapor

public extension Optional {
    static func ?? (lhs: Wrapped?, rhs: @autoclosure () -> Never) -> Wrapped {
        switch lhs {
        case .none: rhs()
        case .some(let unwrapped): return unwrapped
        }
    }
}
