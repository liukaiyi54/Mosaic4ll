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
        for i in 2...16 {
            let img = NSImage.init(named: "\(i)")
            images.add(img!)
        }
        let processor = TileProcessor()
        
        let tiles_data = processor.getTiles(tiles: images)
        
        let targetImage = TargetImage()
        let image_data = targetImage.getImageData(image: NSImage.init(named: "one")!)
        
        let mosaic = Mosaic()
        mosaic.compose(originImages: image_data, tiles: tiles_data)
    }
}

