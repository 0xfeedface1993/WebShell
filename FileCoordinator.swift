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
            var url = URL(fileURLWithPath: urlString).appendingPathComponent(pack.saveFileName)
            
            if fileExists(atPath: url.path) {
                url = URL(fileURLWithPath: urlString).appendingPathComponent(pack.timeStampFileName)
            }
            
            do {
                try pack.pack.revData?.write(to: url)
                print(">>>>>> file saved! <<<<<<")
            } catch {
                print(error)
            }
        }
#elseif os(iOS)
        guard let url = urls(for: .documentDirectory, in: .allDomainsMask).first else {
            print("<<<<<<<<<<<<<<<<<<< DocumentDirectory Not Found! >>>>>>>>>>>>>>>>>>>>")
            return
        }
        
        let fileURL = url.appendingPathComponent(pack.saveFileName)
        
        if fileExists(atPath: fileURL.path) {
            do {
                try removeItem(atPath: fileURL.path)
            } catch {
                print(error)
            }
        }
        
        if createFile(atPath: fileURL.path, contents: pack.pack.revData, attributes: nil) {
            print(">>>>>> file saved! <<<<<<")
        }   else    {
            print("<<<<<<<<<<<<<<<<<<< File Not Save! >>>>>>>>>>>>>>>>>>>>")
        }
#endif
    }
}
