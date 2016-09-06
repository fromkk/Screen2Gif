//
//  Screen2Gif.swift
//  Screen2GifSample
//
//  Created by Kazuya Ueoka on 2016/09/05.
//  Copyright © 2016年 fromKK. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices

public protocol Screen2GifDelegate: class {
    func screen2GifDidStart(screen2Gif: Screen2Gif) -> Void
    func screen2GifDidStop(screen2Gif: Screen2Gif) -> Void
    func screen2GifDidCompletion(screen2Gif: Screen2Gif, url: NSURL?) -> Void
    func screen2Gif(screen2Gif: Screen2Gif, didFailed error: Screen2Gif.Error) -> Void
}

extension Screen2GifDelegate {
    func screen2GifDidStart(screen2Gif: Screen2Gif) {}
    func screen2GifDidStop(screen2Gif: Screen2Gif) {}
    func screen2GifDidCompletion(screen2Gif: Screen2Gif, url: NSURL?) {}
    func screen2Gif(screen2Gif: Screen2Gif, didFailed error: Screen2Gif.Error) {}
}

public protocol Screen2GifType: class {
    associatedtype Completion
    func start(let view: UIView?) -> Void
    func stop() -> Void
}

@objc public class Screen2Gif: NSObject {
    public enum Framerate {
        case f6
        case f10
        case f15
        case f30
        case f60

        func frameInterval() -> Int {
            switch self {
            case .f6:
                return 60 / 6
            case .f10:
                return 60 / 10
            case .f15:
                return 60 / 15
            case .f30:
                return 60 / 30
            case .f60:
                return 60 / 60
            }
        }

        func seconds() -> Double {
            return 1.0 / 60.0 * Double(self.frameInterval())
        }
    }

    public static let shared: Screen2Gif = Screen2Gif()
    private override init() {
        self.queue = dispatch_queue_create(Constants.queue.cStringUsingEncoding(NSUTF8StringEncoding)!, nil)
        super.init()
    }

    private enum Constants {
        static let identifier: String = "me.fromkk.Screen2Gif"
        static let queue: String = "me.fromkk.Screen2Gif.Queue"
    }

    public enum Error: ErrorType {
        case CacheDirectoryCreateFailed
        case TmpDirectoryCreateFailed
        case CacheDirectoryNotfound
        case EmptyView
        case EmptyImage
        case TmpImageCreateFailed
        case FileListGetFailed
        case AnimationGifGenerateFailed
        case RemoveDirectoryFaileds
    }

    /// Public
    public var delegate: Screen2GifDelegate? = nil
    public var frameRate: Framerate = Framerate.f15

    /// Private
    private var view: UIView?
    private var queue: dispatch_queue_t
    private var startTime: NSTimeInterval = NSDate().timeIntervalSince1970
    private var displayLink: CADisplayLink?
    private var isRecording: Bool = false


    /// Paths
    private var currentURL: NSURL?
    private var tmpURL: String = ""

    private func setup() -> Error? {
        /// initial directory
        guard let cacheDir: String = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true).first else {
            return Error.CacheDirectoryNotfound
        }
        let dir: String = "\(cacheDir)/\(Constants.identifier)"
        /// create directory if not exists.
        let fileManager: NSFileManager = NSFileManager.defaultManager()
        if !fileManager.fileExistsAtPath(dir) {
            do {
                try fileManager.createDirectoryAtPath(dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return Error.CacheDirectoryCreateFailed
            }
        }

        let now: NSTimeInterval = NSDate().timeIntervalSince1970

        /// create tmp directory
        let tmpDir: String = "\(dir)/\(Int(now))"
        self.tmpURL = tmpDir
        if !fileManager.fileExistsAtPath(tmpDir) {
            do {
                try fileManager.createDirectoryAtPath(tmpDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return Error.TmpDirectoryCreateFailed
            }
        }

        /// generate url
        let path: String = "\(dir)/\(Int(now)).gif"
        self.currentURL = NSURL(fileURLWithPath: path)

        return nil
    }

    private func snapshot() -> UIImage? {
        guard let view: UIView = self.view else {
            print("view is empty") //TODO: remove later
            return nil
        }

        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    private func setupNotificationObserver() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Screen2Gif.applicationDidEnterBackground(_:)), name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }

    private func unsetupNotificationObserver() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func applicationDidEnterBackground(notification: NSNotification) {
        print(#function)
        self.stop()
    }

    private func failed(with error: Error) {
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            self.delegate?.screen2Gif(self, didFailed: error)
        }
    }
}

extension Screen2Gif: Screen2GifType {
    public typealias Completion = (url: NSURL?) -> Void

    public func start(let view: UIView? = UIApplication.sharedApplication().keyWindow) {
        if self.isRecording {
            return
        }

        self.view = view
        guard let _ = self.view else {
            self.failed(with: Error.EmptyView)
            return
        }

        if let error: Error = self.setup() {
            self.failed(with: error)
            return
        }

        ///displayLink
        self.displayLink = CADisplayLink(target: self, selector: #selector(Screen2Gif.captureFrame(_:)))
        self.displayLink?.frameInterval = self.frameRate.frameInterval()
        self.displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)

        self.delegate?.screen2GifDidStart(self)

        self.setupNotificationObserver()
        self.isRecording = true

        self.startTime = NSDate().timeIntervalSince1970
    }

    func captureFrame(displayLink: CADisplayLink) {
        dispatch_async(self.queue) {
            var snapshot: UIImage?
            dispatch_sync(dispatch_get_main_queue(), {
                snapshot = self.snapshot()
            })

            guard let image: UIImage = snapshot else {
                print("image is empty") //TODO: remove later
                self.failed(with: Error.EmptyImage)
                self.stop()
                return
            }

            guard let data: NSData = UIImagePNGRepresentation(image) else {
                self.failed(with: Error.TmpImageCreateFailed)
                self.stop()
                return
            }

            do {
                let path: String = "\(self.tmpURL)/\(NSDate().timeIntervalSince1970).png"
                try data.writeToFile(path, options: [NSDataWritingOptions.DataWritingAtomic])
            } catch {
                self.failed(with: Error.TmpImageCreateFailed)
                self.stop()
                return
            }
        }
    }

    public func stop() {
        if !self.isRecording {
            return
        }

        self.isRecording = false
        self.unsetupNotificationObserver()

        self.displayLink?.invalidate()

        self.delegate?.screen2GifDidStop(self)
        dispatch_async(self.queue) {
            let files: [String]
            let fileManager: NSFileManager = NSFileManager.defaultManager()
            do {
                let sortDescripter: NSSortDescriptor = NSSortDescriptor(key: "self.doubleValue", ascending: true)
                files = (try fileManager.contentsOfDirectoryAtPath(self.tmpURL) as NSArray).sortedArrayUsingDescriptors([sortDescripter]) as! [String]
            } catch {
                self.failed(with: Error.FileListGetFailed)
                return

            }

            self.generateAnimatinoGif(files, callback: { [weak self] (error) in
                if let error = error {
                    self?.failed(with: error)
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        if let strongSelf = self {
                            strongSelf.delegate?.screen2GifDidCompletion(strongSelf, url: self?.currentURL)
                        }
                    })
                }
            })
        }
    }

    private func generateAnimatinoGif(files: [String], loopCount: Int = 0, callback: (error: Error?) -> Void) -> Void {
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loopCount]]

        if let url = self.currentURL {
            let destination = CGImageDestinationCreateWithURL(url, kUTTypeGIF, files.count, nil)!
            CGImageDestinationSetProperties(destination, fileProperties)

            var lastDate: NSTimeInterval = self.startTime
            files.forEach({ (fileName: String) in
                autoreleasepool({ 
                    let time: NSTimeInterval = NSTimeInterval(fileName.stringByReplacingOccurrencesOfString(".png", withString: ""))!
                    let diff: NSTimeInterval = time - lastDate

                    lastDate = time
                    let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: diff]]

                    let path: String = "\(self.tmpURL)/\(fileName)"
                    guard let image: UIImage = UIImage(contentsOfFile: path) else {
                        return
                    }

                    CGImageDestinationAddImage(destination, image.CGImage!, frameProperties)
                })
            })

            if CGImageDestinationFinalize(destination) {
                callback(error: nil)
            } else {
                callback(error: Error.AnimationGifGenerateFailed)
            }
        }

        let fileManager: NSFileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(self.tmpURL) {
            do {
                try fileManager.removeItemAtURL(NSURL(fileURLWithPath: self.tmpURL))
            } catch {
                self.failed(with: Error.RemoveDirectoryFaileds)
            }
        }
    }
}
