//
//  ViewController.swift
//  Mosaic4ll
//
//  Created by Michael on 31/03/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    var scale: UInt = 4
    let indicator = KRActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60), type: .ballTrianglePath, color:  NSColor(red:0.23, green:0.78, blue:0.32, alpha:1.0), padding: 10.0)
    
    struct Variables {
        static var targetImage: NSImage? = nil
        static var tiles = NSMutableArray()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.stringValue = ""
        self.imageView.wantsLayer = true
        self.imageView.layer?.cornerRadius = 4.0
        self.imageView.layer?.borderWidth = 1.0
        self.imageView.layer?.borderColor = NSColor.gray.cgColor
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
        
        let mosaic = Mosaic()
        
        let alert = NSAlert()
        alert.messageText = "Composing..."
        alert.informativeText = "Just so you know, this may take a while"
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        alert.accessoryView = indicator
        indicator.startAnimating()
        alert.beginSheetModal(for: self.view.window!) { (reponse) in
            if reponse == 1000 && alert.buttons[0].title == "Cancel"{
                mosaic.cancelOperation()
                self.indicator.stopAnimating()
            }
        }
        
        let processor = TileProcessor()
        let tiles_data = processor.getTiles(tiles: ViewController.Variables.tiles)
        
        let targetImage = TargetImage()
        let image_data = targetImage.getImageData(image: ViewController.Variables.targetImage!, scale: scale)
        
        mosaic.compose(originImages: image_data, tiles: tiles_data, complete: {
            OperationQueue.main.addOperation {
                self.view.window?.endSheet(alert.window)
                
                let alert = NSAlert()
                alert.messageText = "Finished!"
                alert.informativeText = ""
                alert.accessoryView = nil
                alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                self.indicator.stopAnimating()
            }
        })
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
                for url in openPanel.urls {
                    let image = NSImage(contentsOfFile: url.path)
                    ViewController.Variables.tiles.add(image!)
                }
                self.label.stringValue = "added \(ViewController.Variables.tiles.count) tiles"
            }
        }
    }
    
}

