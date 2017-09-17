//
//  Image.swift
//  Mosaic4ll
//
//  Created by Michael on 15/09/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Foundation
import Cocoa

extension NSImage {
    func pixelData() -> [Pixel] {
        let bmp = NSBitmapImageRep(data: self.tiffRepresentation!)!
        var data: UnsafeMutablePointer<UInt8> = bmp.bitmapData!
        var r, g, b, a: Int
        var pixels: [Pixel] = []
        
        for _ in 0..<bmp.pixelsHigh {
            for _ in 0..<bmp.pixelsWide {
                r = Int(data.pointee)
                data = data.advanced(by: 1)
                g = Int(data.pointee)
                data = data.advanced(by: 1)
                b = Int(data.pointee)
                data = data.advanced(by: 1)
                a = Int(data.pointee)
                data = data.advanced(by: 1)
                pixels.append(Pixel(r: r, g: g, b: b, a: a))
            }
        }
        data.deinitialize()
        
        return pixels
    }
    
    func resize(width: CGFloat, _ height: CGFloat) -> NSImage {
        let img = NSImage(size: CGSize(width: width, height: height))
        
        img.lockFocus()
        let ctx = NSGraphicsContext.current()
        ctx?.imageInterpolation = .high
        self.draw(in: NSMakeRect(0, 0, width, height), from: NSMakeRect(0, 0, size.width, size.height), operation: .copy, fraction: 1)
        img.unlockFocus()
        
        return img
    }
}
