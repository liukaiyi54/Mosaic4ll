//
//  Mosaic.swift
//  Mosaic4ll
//
//  Created by Michael on 31/03/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Cocoa
import CoreGraphics

var work_queue = NSMutableArray.init()
var result_queue = NSMutableArray.init()


class Mosaic: NSObject {
    func compose(originImages: (largeImage: NSImage, smallImage: NSImage), tiles: (largeTiles: NSArray, smallTiles: NSArray)) {
        let (largeImage, smallImage) = originImages
        let (largeTiles, smallTiles) = tiles
        let allLargeTilesData = NSMutableArray.init()
        let allSmallTilesData = NSMutableArray.init()
        
        for i in 0...largeTiles.count {
            let largePixels = (largeTiles.object(at: i) as! NSImage).pixelData()
            let smallPixels = (smallTiles.object(at: i) as! NSImage).pixelData()
            allLargeTilesData.add(largePixels)
            allSmallTilesData.add(smallPixels)
        }
        
        let mosaic = MosaicImage.init(image: largeImage)
        
        for x in 0...mosaic.xTileCount {
            for y in 0...mosaic.yTileCount {
                let large_box = CGRect(x: x * 50, y: y * 50, width: (x + 1) * 50, height: (y + 1) * 50)
                let small_box = CGRect(x: x * 10, y: y * 10, width: (x + 1) * 10, height: (y + 1) * 10)
                let smallImageCropData = cropImage(image: smallImage, rect: small_box)
                work_queue.add((smallImageCropData, large_box))
            }
        }
        
    }
    
    func buildMosaic(allLargeTilesData: NSArray, largeImage: NSImage) {
        let mosaic = MosaicImage.init(image: largeImage)
        
    }
    
    func fitTiles(allSmallTilesData: NSArray) {
        let tileFitter = TileFitter.init(tilesData: allSmallTilesData)
        
        while work_queue.count > 0 {
            let (smallImageCropData, large_box) = work_queue.object(at: 0) as! (NSImage, CGRect)
            work_queue.removeObject(at: 0)
            let tileIndex = tileFitter.getBestFitTile(image: smallImageCropData)
            result_queue.add(())
            
        }
    }
    
    
}

class TileProcessor: NSObject {
//    var tile_image: NSImage
    func processTile(image: NSImage) -> NSArray {
        let width = image.size.width
        let height = image.size.height
        let min_dimension = min(width, height)
        let w_crop = (width - min_dimension)/2
        let h_crop = (height - min_dimension)/2
        
        let crop = CGRect(x: w_crop, y: h_crop, width: width-w_crop, height: height-h_crop)
        let img = cropImage(image: image, rect: crop)
        
        let largeImage = img.resize(width: 50, 50)
        let smallImage = img.resize(width: 5, 5)
        
        return [largeImage, smallImage]
    }
    
    func getTiles(tiles: NSArray) -> (largeTiles: NSArray, smallTiles: NSArray) {
        let large_tiles = NSMutableArray.init()
        let small_tiles = NSMutableArray.init()
        for tile in tiles {
            let tilesArray = processTile(image: tile as! NSImage)
            large_tiles.add(tilesArray.firstObject!)
            small_tiles.add(tilesArray.lastObject!)
        }
        return (large_tiles.copy() as! NSArray, small_tiles.copy() as! NSArray)
    }
}

class TargetImage: NSObject {
    func getImageData(image: NSImage) -> (largeImage: NSImage, smallImage: NSImage) {
        let width = image.size.width
        let height = image.size.height
        var largeImage = image
        let width_diff = width.truncatingRemainder(dividingBy: 50)/2
        let height_diff = height.truncatingRemainder(dividingBy: 50)/2
        if width_diff > 1 || height_diff > 1 {
            let img = cropImage(image: image, rect: CGRect(x: width_diff, y: height_diff, width: width-width_diff, height: height-height_diff))
            largeImage = img.resize(width: width, height)
        }
        let smallImage = image.resize(width: width/10, height/10)
        
        return (largeImage, smallImage)
    }
}

class TileFitter: NSObject {
    var tilesData: NSArray
    init(tilesData: NSArray) {
        self.tilesData = tilesData
    }
    
    func getTileDiff(image1: NSImage, image2: NSImage, bailOutValue: NSInteger) -> NSInteger {
        var diff = 0
        let pixel1: NSArray = image1.pixelData() as NSArray
        let pixel2: NSArray = image2.pixelData() as NSArray
        
        for i in 0...pixel1.count {
            let p1 = pixel1.object(at: i) as! Pixel
            let p2 = pixel2.object(at: i) as! Pixel
            diff = Int((p1.r-p2.r)*(p1.r-p2.r) + (p1.g-p2.g)*(p1.g-p2.g) + (p1.b-p2.b)*(p1.b-p2.b)) + diff
            if diff > bailOutValue {
                return diff
            }
        }
        return diff
    }
    
    func getBestFitTile(image: NSImage) -> NSInteger {
        var bestFitTileIndex = 0
        var minDiff = Int.max
        var tileIndex = 0
        
        for tileData in self.tilesData {
            let diff = self.getTileDiff(image1: image, image2: tileData as! NSImage, bailOutValue: minDiff)
            if diff < minDiff {
                minDiff = diff
                bestFitTileIndex = tileIndex
            }
            tileIndex += 1
        }
        return bestFitTileIndex
    }
}

class ProgressCounter: NSObject {
    
}

class MosaicImage: NSObject {
    var image: NSImage
    var xTileCount: Int, yTileCount:Int, totalTiles:Int
    init(image: NSImage) {
        self.image = NSImage.init(size: image.size)
        self.xTileCount = (Int)(image.size.width / 50)
        self.yTileCount = (Int)(image.size.height / 50)
        self.totalTiles = self.xTileCount * self.yTileCount
    }
    
    func addTile(tile: NSImage, _coor: (x: CGFloat, y: CGFloat)) {
        let (x, y) = _coor
        let image = NSImage.init(size: CGSize(width: 50, height: 50))
        self.image.lockFocus()
        image.draw(at: NSMakePoint(x, y), from: NSZeroRect, operation: .copy, fraction: 1.0)
        self.image.unlockFocus()
    }
}

func cropImage(image: NSImage, rect: CGRect) -> NSImage {
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    let img = cgImage?.cropping(to: rect)
    
    return NSImage.init(cgImage: img!, size: rect.size)
}

extension NSImage {
    func save() {
        var imageData = self.tiffRepresentation
        let imageRef = NSBitmapImageRep.init(data: imageData!)
        let imageProps = NSDictionary.init(object: NSNumber.init(value: 1.0), forKey: NSImageCompressionFactor as NSCopying)
        imageData = imageRef?.representation(using: NSJPEGFileType, properties: imageProps as! [String : Any])
        do {
            let date = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minutes = calendar.component(.minute, from: date)
            let second = calendar.component(.second, from: date)
            let random = arc4random()%1000
            let time = "\(hour)-\(minutes)-\(second).\(random)"
            try imageData?.write(to: NSURL.init(string: "file:///Users/Michael/Desktop/\(time).jpeg") as! URL)
        } catch {
            print(error)
        }
    }
    
    func pixelData() -> [Pixel] {
        let bmp = self.representations[0] as! NSBitmapImageRep
        var data: UnsafeMutablePointer<UInt8> = bmp.bitmapData!
        var r, g, b, a: UInt8
        var pixels: [Pixel] = []
        
        for _ in 0..<bmp.pixelsHigh {
            for _ in 0..<bmp.pixelsWide {
                r = data.pointee
                data = data.advanced(by: 1)
                g = data.pointee
                data = data.advanced(by: 1)
                b = data.pointee
                data = data.advanced(by: 1)
                a = data.pointee
                data = data.advanced(by: 1)
                pixels.append(Pixel(r: r, g: g, b: b, a: a))
            }
        }
        
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

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
    
    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    var description: String {
        return "RGBA(\(r), \(g), \(b), \(a))"
    }
}

