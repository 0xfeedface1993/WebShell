import Foundation

#if canImport(Combine)
import Combine
#endif

public protocol ContextValue {
    var valueDescription: String { get }
}

extension URL: ContextValue {
    public var valueDescription: String {
        description
    }
}

public enum ValueBox<T>: ContextValue {
    case empty
    case item(T)
    
    public var valueDescription: String {
        switch self {
        case .empty:
            return "empty value."
        case .item(let t):
            return String(describing: t)
        }
    }
    
    public init(_ value: T?) {
        guard let value = value else {
            self = .empty
            return
        }
        self = .item(value)
    }
}
