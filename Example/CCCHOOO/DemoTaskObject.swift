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
import CoreGraphics

let logger = Logger(label: "com.webshell.demo")

final class DemoTaskObject: ObservableObject, Identifiable, @unchecked Sendable {
    typealias DirtyValue = any Dirtyware<URL, String>
    
    @Published var url: String = ""
    @Published var progress = 0.0
    @Published var error: String?
    @Published var title = ""
    @Published var file: URL?
    @Published var tag: String
    
    @Published var state: String = ""
    @Published var formatterProgress: String = ""
    @Published var loading: Bool = false
    @Published var fileSize = ""
    @Published var imageCode: CGImage?
    
    let id = UUID()
    
    let dirty: DirtyValue
    private var updateTask: Task<Void, Never>?
    
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
        Task {
            try await self.observerState()
        }
        await self.download()
        
        loading = false
    }
    
    private func download() async {
        do {
            let fileURL = try await dirty.execute(for: url)
            await update(fileURL)
            logger.error("download file complete at \(fileURL)")
        } catch {
            logger.error("download file failed, \(error)")
            await update(error)
        }
    }
    
    func observerState() async throws {
        let config = AsyncURLSessionConfiguration.shared
        let session = try await AsyncSession(config).context(.host("default"))
        let states = session.downloadNews(.string(tag))
        for try await state in states {
            switch state.value {
            case .state(let value):
                await update(value.progress)
            case .file(_):
                return
            case .error(_):
                return
            }
        }
    }
    
    @MainActor
    func update(_ progress: Progress) async {
        self.progress = progress.fractionCompleted
        if self.progress < 1 {
            self.state = "下载中"
        }
        self.formatterProgress = progress.fractionCompleted.formatted(.percent)
        self.fileSize = progress.totalUnitCount.formatted(.byteCount(style: .decimal))
    }
    
    @MainActor
    func update(_ error: Error) async {
        self.state = "\(error)"
    }
    
    @MainActor
    func update(_ file: URL) async {
        self.file = file
        self.state = "下载完成"
    }
}
