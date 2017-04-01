//
//  ViewController.swift
//  Mosaic4ll
//
//  Created by Michael on 31/03/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBOutlet weak var imageView: NSImageView!
    
    @IBAction func didTapOpen(_ sender: NSButton) {
        let images = NSMutableArray.init()
        for i in 2...7 {
            let img = NSImage.init(named: "\(i)")
            images.add(img!)
        }
        
        let processor = TileProcessor.init()
        let (largeTiles, smallTiles) = processor.getTiles(tiles: images)
        
        for tile in largeTiles {
            let img = tile as! NSImage
//            img.save()
        }
        for tile in smallTiles {
            let img = tile as! NSImage
//            img.save()
        }
        
        let targetImage = TargetImage()
        let (largeImage, smallImage) = targetImage.getImageData(image: NSImage.init(named: "\(6)")!)
        largeImage.save()
        smallImage.save()
        
    }
}

