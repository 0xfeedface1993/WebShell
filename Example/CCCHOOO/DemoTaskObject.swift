//
//  DemoTaskObject.swift
//  WebShellExsample
//
//  Created by john on 2023/9/6.
//  Copyright © 2023 ascp. All rights reserved.
//

import Foundation
import Combine
import WebShell
import Durex
import Logging

let logger = Logger(label: "com.webshell.demo")

final class DemoTaskObject: ObservableObject {
    typealias DirtyValue = any Dirtyware<URL, String>
    
    @Published var url: String = ""
    @Published var progress = 0.0
    @Published var error: String?
    @Published var title = ""
    @Published var file: URL?
    @Published var tag: String
    
    var loading: Bool = false
    let dirty: DirtyValue
    
    init(_ dirty: DirtyValue, tag: String) {
        self.dirty = dirty
        self.tag = tag
    }
    
    @discardableResult
    func title(_ value: String) -> Self {
        title = value
        return self
    }
    
//    @discardableResult
//    func progress(_ value: Double) -> Self {
//        progress = value
//        return self
//    }
    
    @discardableResult
    func url(_ value: String) -> Self {
        url = value
        return self
    }
    
//    @discardableResult
//    func dirty(_ value: DirtyValue) -> Self {
//        dirty = value
//        return self
//    }
    
    @MainActor
    func start() async {
        if loading {
            logger.warning("\(url) already in progress")
            return
        }
        
        loading = true
        defer {
            loading = false
        }
        do {
            Task {
                try await observerState()
            }
            let fileURL = try await dirty.execute(for: url)
            file = fileURL
        } catch {
            logger.error("download file failed, \(error)")
        }
    }
    
    func observerState() async throws {
        let config = AsyncURLSessionConfiguration.shared
        let session = try await AsyncSession(config).context("default")
        let states = session.downloadNews(tag)
        for try await state in states {
            switch state.value {
            case .state(let value):
                await update(value.progress)
            case .file(_):
                break
            case .error(let failure):
                throw failure.error
            }
        }
    }
    
    @MainActor
    func update(_ progress: Progress) async {
        self.progress = Double(progress.completedUnitCount) / Double(max(progress.totalUnitCount, 1))
    }
}
