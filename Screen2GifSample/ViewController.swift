//
//  ViewController.swift
//  Screen2GifSample
//
//  Created by Kazuya Ueoka on 2016/09/05.
//  Copyright © 2016年 fromKK. All rights reserved.
//

import UIKit
import Screen2Gif

func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

class ViewController: UIViewController {

    enum Constants {
        static let recordButtonSize: CGSize = CGSize(width: 80.0, height: 80.0)
    }

    lazy var drawView: DrawableView = {
        let drawView: DrawableView = DrawableView()
        drawView.backgroundColor = UIColor.whiteColor()
        return drawView
    }()
    @IBOutlet weak var recordButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.insertSubview(self.drawView, atIndex: 0)

        self.recordButton.layer.cornerRadius = Constants.recordButtonSize.width / 2.0
        self.recordButton.layer.masksToBounds = true

        Screen2Gif.shared.delegate = self
        Screen2Gif.shared.frameRate = Screen2Gif.Framerate.f15
        // Do any additional setup after loading the view, typically from a nib.
    }

    var didLayouted: Bool = false
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        self.drawView.frame = self.view.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private var isRecording: Bool = false {
        didSet {
            if self.isRecording {
                self.recordButton.setTitle("Stop", forState: UIControlState.Normal)
            } else {
                self.recordButton.setTitle("Record", forState: UIControlState.Normal)
            }
        }
    }
    @IBAction func recordButtonTapped(sender: UIButton) {
        if !self.isRecording {
            Screen2Gif.shared.start()
        } else {
            Screen2Gif.shared.stop()
        }
    }
}

extension ViewController: Screen2GifDelegate {
    func screen2GifDidStart(screen2Gif: Screen2Gif) {
        print(#function)

        self.isRecording = true
    }

    func screen2GifDidStop(screen2Gif: Screen2Gif) {
        print(#function)
    }

    func screen2GifDidCompletion(screen2Gif: Screen2Gif, url: NSURL?) {
        print(#function, url)

        self.isRecording = false
    }

    func screen2Gif(screen2Gif: Screen2Gif, didFailed error: Screen2Gif.Error) {
        print(#function)

        print(error)

        self.isRecording = false
    }
}