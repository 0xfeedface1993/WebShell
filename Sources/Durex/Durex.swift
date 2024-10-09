import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

public protocol ContextValue: Sendable {
    var valueDescription: String { get async }
}

extension URL: ContextValue {
    public var valueDescription: String {
        description
    }
}

extension Array: ContextValue where Element: ContextValue {
    
}

public enum ValueBox<T>: ContextValue where T: Sendable {
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
