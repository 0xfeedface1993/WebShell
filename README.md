
# WebShell

<p align="center">
  <a href="https://github.com/0xfeedface1993/WebShell"><img src="Doc/webshell.png" alt="WebShell" width="210"/></a>
</p>

<p align="center">
  <a href="https://github.com/0xfeedface1993/WebShell"><img src="https://img.shields.io/badge/platforms-iOS%20%20%7C%20macOS-red.svg" /></a>
  <a href="https://github.com/Carthage/Carthage"><img src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat" /></a>
<a href="https://github.com/0xfeedface1993/WebShell/issues"><img src="https://img.shields.io/github/issues/0xfeedface1993/WebShell.svg?style=flat" /></a>
</p></p>

<br>

Better way write worm code with Swift. 

Downloading files from many cloud storage platforms can be cumbersome, requiring multiple page redirects. Through studying the download process, it was discovered that they are all patched together like monsters, and some of the download processes are the same. Theoretically, it is possible to solidify the necessary processes into different modules and link them together, which can be reused across different cloud storage platforms.

This framework serves as the foundation for other apps, and one of the core abilities of the app I am developing is to automatically parse download links and enable one-click downloads using this framework. In the future, more straightforward APIs will be updated.

| Support Site | Module | Status |
| --- | --- | --- |
| www.xueqiupan.com | `DownPage`、`PHPLinks` | done |
| rosefile.net | `AppendDownPath`、`FileIDStringInDomSearchGroup`、`GeneralLinks` | done |
| www.xunniufile.com | `DownPage`、`PHPLinks` | done |
| www.xingyaoclouds.com | `RedirectEnablePage`、`ActionDownPage`、`PHPLinks` | done |
| www.rarp.cc | `HTTPString`、`RedirectEnablePage`、`FileListURLRequestInPageGenerator`、`PHPLinks` | done |
| www.567file.com | - | server 500 error |
| www.xfpan.cc | - | waitting |
| www.kufile.net | - | waitting |

### Ussage

```swift
 let link = "http://www.xueqiupan.com/file-672734.html"
 cancellable = DownPage(.default)
    .join(PHPLinks())
    .join(Saver(.override))
    .publisher(for: link)
    .sink { complete in
        switch complete {
           case .finished:
               break
           case .failure(let error):
               print(">>> download error \(error)")
        }
    } receiveValue: { url in
        print(">>> download file at \(url)")
    }
```

The file will download at your `Downloads` folder.

### Introduction examples

Just confirm `Condom` protocol make simple download HTML page operation become async module

```
struct DownloadWebPage: Condom {
    typealias Input = URL
    typealias Output = String
    
    public func publisher(for inputValue: Input) -> AnyPublisher<Output, Error> {
        // tool for data -> string 
        StringParserDataTask(request: .init(url: inputValue), encoding: .utf8)
            .publisher()
    }
    
    public func empty() -> AnyPublisher<Output, Error> {
        Fail(error: URLError(.badURL)).eraseToAnyPublisher()
    }
}
``` 

Then get publisher out of it，and sink to fire it up!
```
DownloadWebPage()
    .publisher(for: link)
    .sink { complete in
        switch complete {
           case .finished:
               break
           case .failure(let error):
               print(">>> download error \(error)")
        }
    } receiveValue: { text in
        print(">>> html: \(text)")
    }
```

## Installation

#### carthage
[Carthage](https://github.com/Carthage/Carthage) is a simple, decentralized dependency manager for Cocoa.

Specify WebShell into your project's `Cartfile`:

```ogdl
github "0xfeedface1993/WebShell" ~> 3.0
```
#### Swift Package Manager (SPM)

From Xcode, select from the menu File > Swift Packages > Add Package Dependency
Specify the URL https://github.com/0xfeedface1993/WebShell

##
As you can see, this project need more work, so if you want join me, any pull request will be helpful!

## Thanks! Have a good day!
