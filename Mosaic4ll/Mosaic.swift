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
        
        let mosaic = MosaicImage.init(size: largeImage.size)
        
        let operationQueue = OperationQueue.main
        operationQueue.maxConcurrentOperationCount = 3
        
        
        let cgImage = smallImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let op = BlockOperation (block: {
            for x in 0...mosaic.xTileCount-1 {
                for y in 0...mosaic.yTileCount-1 {
                    let large_box = CGRect(x: x * 50, y: y * 50, width: 50, height: 50)
                    let small_box = CGRect(x: x * 10, y: y * 10, width: 10, height: 10)
                    let smallImageCropData = cropImage(image: cgImage, rect: small_box)
                    work_queue.add((smallImageCropData, large_box))
                }
            }
        })
        operationQueue.addOperation(op)
        
        let operation: BlockOperation = BlockOperation (block: {
            self.fitTiles(allSmallTiles: smallTiles)
            let anotherOperation: BlockOperation = BlockOperation (block: {
                self.buildMosaic(allLargeTiles: largeTiles, largeImage: largeImage)
            })
            operationQueue.addOperation(anotherOperation)
        })
        operationQueue.addOperation(operation)
        
    }
    
    func buildMosaic(allLargeTiles: NSArray, largeImage: NSImage) {
        let mosaic = MosaicImage.init(size: largeImage.size)
        mosaic.addTileAndSave(tiles: allLargeTiles)
    }
    
    func fitTiles(allSmallTiles: NSArray) {
        let tileFitter = TileFitter.init(tilesData: allSmallTiles)
        let allTilesPixelData = tileFitter.getAllTilesPixelData(tiles: allSmallTiles)
        while work_queue.count > 0 {
            let (smallImageCropData, large_box) = work_queue.object(at: 0) as! (NSImage, CGRect)
            work_queue.removeObject(at: 0)
            let tileIndex = tileFitter.getBestFitTile(image: smallImageCropData, allTiles: allTilesPixelData)
            result_queue.add((large_box, tileIndex))
        }
    }
}

class TileProcessor: NSObject {
    func processTile(image: NSImage) -> NSArray {
        let width = image.size.width
        let height = image.size.height
        let min_dimension = min(width, height)
        let w_crop = (width - min_dimension)/2
        let h_crop = (height - min_dimension)/2
        
        let crop = CGRect(x: w_crop, y: h_crop, width: width-w_crop*2, height: height-h_crop*2)
        let img = cropImage(image: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, rect: crop)
        
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
        let width = image.size.width*8
        let height = image.size.height*8
        var largeImage = image
        let width_diff = width.truncatingRemainder(dividingBy: 50)/2
        let height_diff = height.truncatingRemainder(dividingBy: 50)/2
        if width_diff > 0 || height_diff > 0 {
            let img = cropImage(image: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, rect: CGRect(x: width_diff, y: height_diff, width: width-width_diff*2, height: height-height_diff*2))
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
    
    func getTileDiff(imagePixelData: [Pixel], tilePixelData: NSArray, bailOutValue: NSInteger) -> NSInteger {
        var diff = 0
        let pixel1 = imagePixelData
        let pixel2 = tilePixelData
        let minLength = min(pixel1.count, pixel2.count)
        
        for i in 0...minLength-1 {
            let p1 = pixel1[i]
            let p2 = pixel2[i] as! Pixel
            diff = Int((p1.r-p2.r)*(p1.r-p2.r) + (p1.g-p2.g)*(p1.g-p2.g) + (p1.b-p2.b)*(p1.b-p2.b)) + diff
            if diff > bailOutValue {
                return diff
            }
        }
        return diff
    }
    
    func getBestFitTile(image: NSImage, allTiles: NSArray) -> NSInteger {
        var bestFitTileIndex = 0
        var minDiff = Int.max
        var tileIndex = 0
    
        let allTilesPixelData = allTiles
        let imagePixelData = image.pixelData()
        
        for tilePixel in allTilesPixelData {
            let diff = getTileDiff(imagePixelData: imagePixelData, tilePixelData: tilePixel as! NSArray, bailOutValue: minDiff)
            if diff < minDiff {
                minDiff = diff
                bestFitTileIndex = tileIndex
            }
            tileIndex += 1
        }
        
        return bestFitTileIndex
    }
    
    func getAllTilesPixelData(tiles: NSArray) -> NSArray {
        let allTilesPixelData = NSMutableArray.init()
        
        for tile in tiles {
            let pixel = (tile as! NSImage).pixelData()
            allTilesPixelData.add(pixel)
        }
        return allTilesPixelData
    }
}

class ProgressCounter: NSObject {
    
}

class MosaicImage: NSObject {
    var size: NSSize
    var xTileCount: Int, yTileCount:Int, totalTiles:Int
    init(size: NSSize) {
        self.size = size
        self.xTileCount = (Int)(size.width / 50)
        self.yTileCount = (Int)(size.height / 50)
        self.totalTiles = self.xTileCount * self.yTileCount
    }
    
    func addTileAndSave(tiles: NSArray) {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(self.size.width), pixelsHigh: Int(self.size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSDeviceRGBColorSpace, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = self.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(NSGraphicsContext(bitmapImageRep: bitmap))
        
        while result_queue.count > 0 {
            let (large_box, tileIndex) = result_queue.object(at: 0) as! (CGRect, NSInteger)
            result_queue.removeObject(at: 0)
            let tileData = tiles[tileIndex] as! NSImage
            tileData.draw(at: NSMakePoint(large_box.origin.x, self.size.height - large_box.origin.y - 50), from: NSZeroRect, operation: .copy, fraction: 1.0)
            //坐标系转化，draw方法是以左下角为坐标原点，此处改为从左上角为原点
        }
        NSGraphicsContext.restoreGraphicsState()
        
        let imageData = bitmap.representation(using: NSJPEGFileType, properties: [NSImageCompressionFactor: 0.5])!
        do {
            let filePath = "file:///Users/Michael/Pictures/mosaic.jpeg"
            try imageData.write(to: NSURL.init(string: filePath) as! URL)
            let workspace = NSWorkspace.shared()
            workspace.openFile(filePath)
        } catch {
            print(error)
        }
    }
}

func cropImage(image: CGImage, rect: CGRect) -> NSImage {
    let img = image.cropping(to: rect)
    return NSImage.init(cgImage: img!, size: rect.size)
}

extension NSImage {
    func save() {
        var imageData = self.tiffRepresentation
        let imageRef = NSBitmapImageRep.init(data: imageData!)
        let imageProps = NSDictionary.init(object: NSNumber.init(value: 0.5), forKey: NSImageCompressionFactor as NSCopying)
        imageData = imageRef?.representation(using: NSJPEGFileType, properties: imageProps as! [String : Any])
        do {
            let date = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minutes = calendar.component(.minute, from: date)
            let second = calendar.component(.second, from: date)
            let random = arc4random()%1000
            let time = "\(hour)-\(minutes)-\(second).\(random)"
            try imageData?.write(to: NSURL.init(string: "file:///Users/Michael/Desktop/image/\(time).jpeg") as! URL)
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

