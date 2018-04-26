//
//  FileCoordinator.swift
//  WebShell
//
//  Created by virus1993 on 2018/3/1.
//  Copyright © 2018年 ascp. All rights reserved.
//

#if os(macOS)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

extension FileManager {
    func save(pack: PCDownloadTask) {
#if os(macOS)
        // 保存到下载文件夹下
        if let urlString = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first {
            let url = URL(fileURLWithPath: urlString).appendingPathComponent(pack.fileName)
            do {
                try pack.pack.revData?.write(to: url)
                print(">>>>>> file saved! <<<<<<")
            } catch {
                print(error)
            }
        }
#elseif os(iOS)
        guard let url = urls(for: .documentDirectory, in: .allDomainsMask).first?.appendingPathComponent(pack.fileName), createFile(atPath: url.path, contents: pack.pack.revData, attributes: nil) else {
            print("<<<<<<<<<<<<<<<<<<< File Not Save! >>>>>>>>>>>>>>>>>>>>")
            return
        }
        print(">>>>>> file saved! <<<<<<")
#endif
    }
}
