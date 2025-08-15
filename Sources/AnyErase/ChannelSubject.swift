//
//  File.swift
//  WebShell
//
//  Created by york on 2025/6/21.
//

import Foundation
import AsyncAlgorithms
import AsyncBroadcaster

public struct ChannelSubject<T: Sendable>: Sendable {
    private let channel: AsyncChannel<T>
    private let broadcast: AsyncBroadcaster<T>
    
    public init(_ replay: AsyncBuffer = .latest(1)) {
        let channel = AsyncChannel<T>()
        self.channel = channel
        self.broadcast = AsyncBroadcaster(replay: replay, sequence: channel)
    }
    
    public func send(_ element: T) async {
        await channel.send(element)
    }
    
    public func subscribe() -> AsyncBroadcaster<T> {
        broadcast
    }
    
    public func subscribe<V: AsyncSequence>(_ replay: AsyncBuffer = .latest(1), transfrom: @Sendable @escaping (AsyncBroadcaster<T>) -> V) -> AsyncBroadcaster<V.Element> {
        AsyncBroadcaster(replay: replay, sequence: transfrom(broadcast))
    }
    
    public func transfrom<V: AsyncSequence>(_ transfrom: @Sendable @escaping (AsyncBroadcaster<T>) -> V) -> V {
        transfrom(broadcast)
    }
    
    public func finished() {
        channel.finish()
    }
}
