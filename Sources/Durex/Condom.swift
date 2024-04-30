//
//  File.swift
//  
//
//  Created by john on 2023/2/15.
//

import Foundation

#if COMBINE_LINUX && canImport(CombineX)
import CombineX
#else
import Combine
#endif

public protocol Condom<Output, Input> {
    associatedtype Input: ContextValue
    associatedtype Output: ContextValue
    
    /// 捕获输入，返回异步任务
    /// - Parameter inputValue: 输入数据
    /// - Returns: AnyPublisher异步任务
    func publisher(for inputValue: Input) -> AnyPublisher<Output, Error>
    /// 没有输入数据，返回异步结果，可以返回Error
    /// - Returns: AnyPublisher异步任务
    func empty() -> AnyPublisher<Output, Error>
}

extension Condom {
    public func join<T>(_ box: T) -> AnyCondom<Self.Input, T.Output> where T: Condom, T.Input == Self.Output {
        AnyCondom(self, last: box)
    }
    
    public func eraseToAnyCondom() -> AnyCondom<Input, Output> {
        AnyCondom(self)
    }
}

public protocol SessionableCondom: Condom {
    var key: AnyHashable { get }
    
    func sessionKey(_ value: AnyHashable) -> Self
}

public protocol Dirtyware<Output, Input> {
    associatedtype Input: ContextValue
    associatedtype Output: ContextValue
    
    /// 捕获输入，返回异步任务
    /// - Parameter inputValue: 输入数据
    /// - Returns: AnyPublisher异步任务
    func execute(for inputValue: Input) async throws -> Output
}

extension Dirtyware {
    public func join<T>(_ box: T) -> AnyDirtyware<Self.Input, T.Output> where T: Dirtyware, T.Input == Self.Output {
        AnyDirtyware(self, last: box)
    }
    
    public func eraseToAnyDirtyware() -> AnyDirtyware<Input, Output> {
        AnyDirtyware(self)
    }
}

public protocol SessionableDirtyware: Dirtyware {
    var key: AnyHashable { get }
    var configures: AsyncURLSessionConfiguration { get }
    
    func sessionKey(_ value: AnyHashable) -> Self
}
