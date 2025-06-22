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
    
    public init() {
        let channel = AsyncChannel<T>()
        self.channel = channel
        self.broadcast = AsyncBroadcaster(replay: .latest(1), sequence: channel)
    }
    
    public func send(_ element: T) async {
        await channel.send(element)
    }
    
    public func subscribe() -> AsyncBroadcaster<T> {
        broadcast
    }
    
    public func finished() {
        channel.finish()
    }
}
