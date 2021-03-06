//
//  Mosaic.swift
//  Mosaic4ll
//
//  Created by Michael on 31/03/2017.
//  Copyright © 2017 Michael. All rights reserved.
//

import Cocoa
import CoreGraphics

var work_queue = NSMutableArray()
var result_queue = NSMutableArray()

class Mosaic: NSObject {
    let operationQueue = OperationQueue()

    func compose(originImages: (largeImage: NSImage, smallImage: NSImage), tiles: (largeTiles: NSArray, smallTiles: NSArray), complete: @escaping () -> Void) {
        let (largeImage, smallImage) = originImages
        let (largeTiles, smallTiles) = tiles
        
        let mosaic = MosaicImage(size: largeImage.size)
        
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
        
        let mosaicBuildPrework = MosaicBuildPrework(allTiles: smallTiles)
        mosaicBuildPrework.name = "Prework"
        mosaicBuildPrework.addDependency(op)
        mosaicBuildPrework.completionBlock = {
            if mosaicBuildPrework.isCancelled {
                return
            }
            
            self.buildMosaic(allLargeTiles: largeTiles, largeImage: largeImage)
            complete()
        }
        operationQueue.addOperation(mosaicBuildPrework)
    }
    
    func cancelOperation() {
        operationQueue.cancelAllOperations()
    }
    
    func buildMosaic(allLargeTiles: NSArray, largeImage: NSImage) {
        let mosaic = MosaicImage(size: largeImage.size)
        mosaic.addTileAndSave(tiles: allLargeTiles)
    }
}

class MosaicBuildPrework: Operation {
    var allTiles: NSArray
    init(allTiles: NSArray) {
        self.allTiles = allTiles
    }
    
    override func main() {
        if self.isCancelled {
            return;
        }
        
        let tileFitter = TileFitter(tilesData: self.allTiles)
        let allTilesPixelData = tileFitter.getAllTilesPixelData(tiles: self.allTiles)
        while work_queue.count > 0 {
            if self.isCancelled {
                return
            }
            let (smallImageCropImage, large_box) = work_queue.object(at: 0) as! (NSImage, CGRect)
            work_queue.removeObject(at: 0)
            let tileIndex = tileFitter.getBestFitTile(image: smallImageCropImage, allTiles: allTilesPixelData)
            result_queue.add((large_box, tileIndex))
        }
    }
}

class TileProcessor: NSObject {
    func processTile(image: NSImage) -> (NSImage, NSImage) {
        let width = image.size.width
        let height = image.size.height
        let min_dimension = min(width, height)
        let w_crop = (width - min_dimension)/2
        let h_crop = (height - min_dimension)/2
        
        let crop = CGRect(x: w_crop, y: h_crop, width: width-w_crop*2, height: height-h_crop*2)
        let img = cropImage(image: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, rect: crop)
        
        let largeImage = img.resize(width: 50, 50)
        let smallImage = img.resize(width: 5, 5)
        
        return (largeImage, smallImage)
    }
    
    func getTiles(tiles: NSArray) -> (NSArray, NSArray) {
        let large_tiles = NSMutableArray()
        let small_tiles = NSMutableArray()
        for tile in tiles {
            let (largeImage, smallImage) = processTile(image: tile as! NSImage)
            large_tiles.add(largeImage)
            small_tiles.add(smallImage)
        }
        return (large_tiles.copy() as! NSArray, small_tiles.copy() as! NSArray)
    }
}

class TargetImage: NSObject {
    func getImageData(image: NSImage, scale: UInt) -> (NSImage, NSImage) {
        let width = image.size.width*CGFloat(scale)
        let height = image.size.height*CGFloat(scale)
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
    
    private func getTileDiff(imagePixelData: [Pixel], tilePixelData: NSArray, bailOutValue: NSInteger) -> NSInteger {
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
        let allTilesPixelData = NSMutableArray()
        
        for tile in tiles {
            let pixel = (tile as! NSImage).pixelData()
            allTilesPixelData.add(pixel)
        }
        return allTilesPixelData
    }
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
            let filePath = "file://"+NSHomeDirectory()+"/Pictures/mosaic.jpeg"
            try imageData.write(to: NSURL(string: filePath)! as URL)
            let workspace = NSWorkspace.shared()
            workspace.openFile(NSHomeDirectory()+"/Pictures/mosaic.jpeg")
        } catch {
            print(error)
        }
    }
}

func cropImage(image: CGImage, rect: CGRect) -> NSImage {
    let img = image.cropping(to: rect)
    return NSImage(cgImage: img!, size: rect.size)
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

