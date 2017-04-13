//
//  ViewController.swift
//  Mosaic4ll
//
//  Created by Michael on 31/03/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    struct Variables {
        static var targetImage: NSImage? = nil
        static var tiles = NSMutableArray()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.stringValue = " "
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var label: NSTextField!
    let progressIndicator = NSProgressIndicator()
    
    
    @IBAction func selectTarget(_ sender: NSButton) {
        let openPanel = NSOpenPanel();
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()+"/Desktop")
        openPanel.allowedFileTypes = ["jpeg", "jpg"]
        openPanel.begin { (i) in
            if i == NSModalResponseOK {
                print(openPanel.url!)
                ViewController.Variables.targetImage = NSImage(contentsOfFile: openPanel.url!.path)!
                self.imageView.image = ViewController.Variables.targetImage
            }
        }
    }
    
    @IBAction func compose(_ sender: NSButton) {
        if ViewController.Variables.targetImage == nil {
            return
        }
        if ViewController.Variables.tiles.count == 0  {
            return
        }
        
        let processor = TileProcessor()
        let tiles_data = processor.getTiles(tiles: ViewController.Variables.tiles)
        
        let targetImage = TargetImage()
        let image_data = targetImage.getImageData(image: ViewController.Variables.targetImage!)
        
        let mosaic = Mosaic()
        mosaic.compose(originImages: image_data, tiles: tiles_data)
    }
    
    @IBAction func selectTiles(_ sender: NSButton) {
        let openPanel = NSOpenPanel();
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()+"/Desktop")
        openPanel.allowedFileTypes = ["jpeg", "jpg"]
        openPanel.begin { (i) in
            if i == NSModalResponseOK {
                print(openPanel.urls)
                for url in openPanel.urls {
                    let image = NSImage(contentsOfFile: url.path)
                    ViewController.Variables.tiles.add(image!)
                }
                self.label.stringValue = "added \(openPanel.urls.count) tiles"
            }
        }
    }
}

