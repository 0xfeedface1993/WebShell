
# WebShell

<!--<p align="center">-->
<!--  <a href="https://github.com/0xfeedface1993/WebShell"><img src="docs_markdown/images/flexlayout-logo-text.png" alt="FlexLayout" width="210"/></a>-->
<!--</p>-->

<p align="center">
  <a href="https://github.com/0xfeedface1993/WebShell"><img src="https://img.shields.io/badge/platforms-iOS%20%20%7C%20macOS-red.svg" /></a>
  <a href="https://github.com/Carthage/Carthage"><img src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat" /></a>
<a href="https://github.com/0xfeedface1993/WebShell/issues"><img src="https://img.shields.io/github/issues/0xfeedface1993/WebShell.svg?style=flat" /></a>
</p></p>

<br>

A shell could opreate WKWebView in Swift &amp; JS, it run like internet worm, but not in harm way.

## Installation

#### carthage
[Carthage](https://github.com/Carthage/Carthage) is a simple, decentralized dependency manager for Cocoa.

Specify WebShell into your project's `Cartfile`:

```ogdl
github "0xfeedface1993/WebShell" ~> 2.2
```

### Ussage

```ogdl
let pipline = PCPipeline.share
pipline.delegate = self
let riffle = pipline.add(url: "http://www.chooyun.com/file-51745.html", password: "12345x")
```

Then download task will automatic start.

if you want update information, comfirm PCPiplineDelegate:

```ogdl
extension ViewController: PCPiplineDelegate {
    func pipline(didAddRiffle riffle: PCWebRiffle) {
        print("\n(((((((((((((((((((((( Pipline didAddRiffle Begin )))))))))))))))))))))))")
        
        print("(((((((((((((((((((((( Pipline didAddRiffle End )))))))))))))))))))))))\n")
    }
    
    func pipline(didUpdateTask task: PCDownloadTask) {
        print("(((((((((((((((((((((( Pipline didUpdateTask Begin )))))))))))))))))))))))")
        
        print("(((((((((((((((((((((( Pipline didUpdateTask End )))))))))))))))))))))))")
    }
    
    func pipline(didFinishedTask task: PCDownloadTask, error: Error?) {
        print("\n(((((((((((((((((((((( Pipline didFinishedTask Begin )))))))))))))))))))))))")
        
        print("(((((((((((((((((((((( Pipline didFinishedTask End )))))))))))))))))))))))\n")
    }
    
    func pipline(didFinishedRiffle riffle: PCWebRiffle) {
        print("\n(((((((((((((((((((((( Pipline didFinishedRiffle Begin )))))))))))))))))))))))")
        print("************ Not Found File Link: \(riffle.mainURL?.absoluteString ?? "** no link **")")
        print("(((((((((((((((((((((( Pipline didFinishedRiffle End )))))))))))))))))))))))\n")
    }
 }
```

The file will download at your `Downloads` folder.

##
As you can see, this project need more work, so if you want join me, any pull request will be helpful!

## Thanks! Have a good day!
