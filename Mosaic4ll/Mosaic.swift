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
//        let allLargeTilesData = NSMutableArray.init()
//        let allSmallTilesData = NSMutableArray.init()
        
//        for i in 0...largeTiles.count-1 {
//            let largePixels = (largeTiles.object(at: i) as! NSImage).pixelData()
//            let smallPixels = (smallTiles.object(at: i) as! NSImage).pixelData()
//            allLargeTilesData.add(largePixels)
//            allSmallTilesData.add(smallPixels)
//        }
        
        let mosaic = MosaicImage.init(image: largeImage)
        
        for x in 0...mosaic.xTileCount-1 {
            for y in 0...mosaic.yTileCount-1 {
                let large_box = CGRect(x: x * 50, y: y * 50, width: (x + 1) * 50, height: (y + 1) * 50)
                let small_box = CGRect(x: x * 10, y: y * 10, width: (x + 1) * 10, height: (y + 1) * 10)
                let smallImageCropData = cropImage(image: smallImage, rect: small_box)
                work_queue.add((smallImageCropData, large_box))
            }
        }
        
        fitTiles(allSmallTiles: smallTiles)
        buildMosaic(allLargeTiles: largeTiles, largeImage: largeImage)
    }
    
    func buildMosaic(allLargeTiles: NSArray, largeImage: NSImage) {
        let mosaic = MosaicImage.init(image: largeImage)
        
        while result_queue.count > 0 {
            let (large_box, tileIndex) = result_queue.object(at: 0) as! (CGRect, NSInteger)
            result_queue.removeObject(at: 0)
            let tile_data = allLargeTiles[tileIndex] as! NSImage
            mosaic.addTile(tile: tile_data, coor: (x: large_box.origin.x, y: large_box.origin.y, height: largeImage.size.height))
        }
        
        mosaic.image.save()
    }
    
    func fitTiles(allSmallTiles: NSArray) {
        let tileFitter = TileFitter.init(tilesData: allSmallTiles)
        
        while work_queue.count > 0 {
            let (smallImageCropData, large_box) = work_queue.object(at: 0) as! (NSImage, CGRect)
            work_queue.removeObject(at: 0)
            let tileIndex = tileFitter.getBestFitTile(image: smallImageCropData)
            result_queue.add((large_box, tileIndex))
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
        
        let crop = CGRect(x: w_crop, y: h_crop, width: width-w_crop*2, height: height-h_crop*2)
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
        if width_diff > 0 || height_diff > 0 {
            let img = cropImage(image: image, rect: CGRect(x: width_diff, y: height_diff, width: width-width_diff*2, height: height-height_diff*2))
            largeImage = img
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
        let pixel1 = image1.pixelData() as Array
        let pixel2 = image2.pixelData() as Array
        
        let minLength = min(pixel1.count, pixel2.count)
        
        for i in 0...minLength-1 {
            let p1 = pixel1[i]
            let p2 = pixel2[i]
            print(p1)
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
    
    func addTile(tile: NSImage, coor: (x: CGFloat, y: CGFloat, height: CGFloat)) {
        let (x, y, height) = coor
        self.image.lockFocus()
        //坐标系转化，draw方法是以左下角为坐标原点，此处改为从左上角为原点
        tile.draw(at: NSMakePoint(x, height-y-50), from: NSZeroRect, operation: .copy, fraction: 1.0)
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
        let bmp = NSBitmapImageRep.init(data: self.tiffRepresentation!)!
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
    var r: Int
    var g: Int
    var b: Int
    var a: Int
    
    init(r: Int, g: Int, b: Int, a: Int) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

