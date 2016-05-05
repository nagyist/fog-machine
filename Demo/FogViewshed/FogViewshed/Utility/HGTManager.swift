import Foundation
import MapKit

public class HGTManager {
    static func isFileInDocuments(fileName: String) -> Bool {
        let fileManager: NSFileManager = NSFileManager.defaultManager()
        let documentsPath: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let url = NSURL(fileURLWithPath: documentsPath).URLByAppendingPathComponent(fileName)
        return fileManager.fileExistsAtPath(url.path!)
    }
    
    static func copyHGTFilesToDocumentsDir() {
        let prefs = NSUserDefaults.standardUserDefaults()
        
        // copy the data over to documents dir, if it's never been done.
        if !prefs.boolForKey("hasCopyData") {
            
            let fromPath:String = NSBundle.mainBundle().resourcePath!
            let toPath: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            
            do {
                let fileManager = NSFileManager.defaultManager()
                let resourceFiles:[String] = try fileManager.contentsOfDirectoryAtPath(fromPath)
                
                for file in resourceFiles {
                    if file.hasSuffix(".hgt") {
                        let fromFilePath = fromPath + "/" + file
                        let toFilePath = toPath + "/" + file
                        if (fileManager.fileExistsAtPath(toFilePath) == false) {
                            try fileManager.copyItemAtPath(fromFilePath, toPath: toFilePath)
                            NSLog("Copying " + file + " to documents directory.")
                        }
                    }
                }
                prefs.setValue(true, forKey: "hasCopyData")
            } catch let error as NSError  {
                NSLog("Problem copying files: \(error.localizedDescription)")
            }
        }
    }
    
    static private func getLocalHGTFileMap() -> [String:HGTFile] {
        var hgtFiles:[String:HGTFile] = [String:HGTFile]()
        let documentsUrl:NSURL =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        do {
            let hgtPaths:[NSURL] = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions()).filter{ $0.pathExtension == "hgt" }

            for hgtpath in hgtPaths {
                hgtFiles[hgtpath.lastPathComponent!] = HGTFile(path: hgtpath)
                
            }
        } catch let error as NSError {
            NSLog("Error displaying HGT file: \(error.localizedDescription)")
        }

        return hgtFiles
    }
    
    static func getLocalHGTFiles() -> [HGTFile] {
        return Array(getLocalHGTFileMap().values)
    }
    
    static func getLocalHGTFileByName(filename:String) -> HGTFile? {
        return getLocalHGTFileMap()[filename]
    }
    

    /**
     
     see https://dds.cr.usgs.gov/srtm/version2_1/Documentation/Quickstart.pdf for more information
     
     SRTM data are distributed in two levels: SRTM1 (for the U.S. and its territories
     and possessions) with data sampled at one arc-second intervals in latitude and
     longitude, and SRTM3 (for the world) sampled at three arc-seconds. Three
     arc-second data are generated by three by three averaging of the one
     arc-second samples.
     
     Data are divided into one by one degree latitude and longitude tiles in
     "geographic" projection, which is to say a raster presentation with equal
     intervals of latitude and longitude in no projection at all but easy to manipulate
     and mosaic.
     
     File names refer to the latitude and longitude of the lower left corner of
     the tile - e.g. N37W105 has its lower left corner at 37 degrees north
     latitude and 105 degrees west longitude. To be more exact, these
     coordinates refer to the geometric center of the lower left pixel, which in
     the case of SRTM3 data will be about 90 meters in extent.
     
     Height files have the extension .HGT and are signed two byte integers. The
     bytes are in Motorola "big-endian" order with the most significant byte first,
     directly readable by systems such as Sun SPARC, Silicon Graphics and Macintosh
     computers using Power PC processors. DEC Alpha, most PCs and Macintosh
     computers built after 2006 use Intel ("little-endian") order so some byte-swapping
     may be necessary. Heights are in meters referenced to the WGS84/EGM96 geoid.
     Data voids are assigned the value -32768.
     
     SRTM3 files contain 1201 lines and 1201 samples. The rows at the north
     and south edges as well as the columns at the east and west edges of each
     cell overlap and are identical to the edge rows and columns in the adjacent
     cell. SRTM1 files contain 3601 lines and 3601 samples, with similar overlap.

     
     
     
     NOTE:
     For the purpose of this application, we will ignore the first row (top row) and the last column (right column)
     in the hgt files.  This will be done to avoid dealing with the overlap that extists across the hgt files.  
     Doing this will provide a perfect tiling.
     
     */
    static func getElevationGrid(axisOrientedBoundingBox:AxisOrientedBoundingBox) -> ElevationDataGrid {
        
        // TODO: pass this in
        let resolutioni:Int = Srtm.SRTM3_RESOLUTION
        let resolutiond:Double = Double(resolutioni)
        
        // this is the size of a cell in degrees
        let cellSizeInDegrees:Double = 1.0/resolutiond
        
        // expand the bounds of the bounding box to snap to the srtm grid size
        
        // lower left
        let llLatCell:Double = axisOrientedBoundingBox.getLowerLeft().latitude
        let llLatGrid:Double = floor(llLatCell) - (cellSizeInDegrees/2.0)
        let llLatCellGrided:Double = llLatGrid + (floor((llLatCell - llLatGrid)*resolutiond)*cellSizeInDegrees)
        
        let llLonCell:Double = axisOrientedBoundingBox.getLowerLeft().longitude
        let llLonGrid:Double = floor(llLonCell) - (cellSizeInDegrees/2.0)
        let llLonCellGrided:Double = llLonGrid + (floor((llLonCell - llLonGrid)*resolutiond)*cellSizeInDegrees)
        
        // upper right
        let urLatCell:Double = axisOrientedBoundingBox.getUpperRight().latitude
        let urLatGrid:Double = floor(urLatCell) - (cellSizeInDegrees/2.0)
        let urLatCellGrided:Double = urLatGrid + (ceil((urLatCell - urLatGrid)*resolutiond)*cellSizeInDegrees)

        let urLonCell:Double = axisOrientedBoundingBox.getUpperRight().longitude
        let urLonGrid:Double = floor(urLonCell) - (cellSizeInDegrees/2.0)
        let urLonCellGrided:Double = urLonGrid + (ceil((urLonCell - urLonGrid)*resolutiond)*cellSizeInDegrees)
        
        // this is the bounding box, snapped to the grid
        let griddedAxisOrientedBoundingBox:AxisOrientedBoundingBox = AxisOrientedBoundingBox(lowerLeft: CLLocationCoordinate2DMake(llLatCellGrided, llLonCellGrided), upperRight: CLLocationCoordinate2DMake(urLatCellGrided, urLonCellGrided))
        
        // get hgt files of interest
        var hgtFilesOfInterest:[HGTFile] = [HGTFile]()
        
        let llLat:Double = griddedAxisOrientedBoundingBox.getLowerLeft().latitude
        let urLat:Double = griddedAxisOrientedBoundingBox.getUpperRight().latitude
        var iLat:Double = llLat
        
        let llLon:Double = griddedAxisOrientedBoundingBox.getLowerLeft().longitude
        let urLon:Double = griddedAxisOrientedBoundingBox.getUpperRight().longitude
        var iLon:Double = llLon

        // get all the files that are covered by this bounding box
        while(iLon <= urLon) {
            while(iLat <= urLat) {
                let hgtFile:HGTFile? = HGTManager.getLocalHGTFileByName(HGTFile.coordinateToFilename(CLLocationCoordinate2DMake(iLat, iLon), resolution: resolutioni))
                if(hgtFile != nil) {
                    hgtFilesOfInterest.append(hgtFile!)
                }
                iLat = iLat + 1.0
            }
            iLon = iLon + 1.0
        }
        
        let elevationDataWidth:Int = Int((griddedAxisOrientedBoundingBox.getUpperRight().longitude - griddedAxisOrientedBoundingBox.getLowerLeft().longitude)*(1200.0))
        let elevationDataHeight:Int = Int((griddedAxisOrientedBoundingBox.getUpperRight().latitude - griddedAxisOrientedBoundingBox.getLowerLeft().latitude)*(1200.0))
        
        var elevationData:[[Int]] = [[Int]](count:elevationDataWidth, repeatedValue:[Int](count:elevationDataHeight, repeatedValue:Srtm.DATA_VOID))
        
        for hgtFileOfInterest:HGTFile in hgtFilesOfInterest {
            
            let hgtFileBoundingBox:AxisOrientedBoundingBox = hgtFileOfInterest.getBoundingBox()
            
            // make sure this hgtfile intersets the bounding box
            if(hgtFileBoundingBox.intersectionExists(griddedAxisOrientedBoundingBox)) {
                // find the intersection
                let hgtAreaOfInterest:AxisOrientedBoundingBox = hgtFileBoundingBox.intersection(griddedAxisOrientedBoundingBox)
                
                // we need to read data from the upper left of the intersection to the lower right of the intersection
                var upperLeftIndex:(Int, Int) = hgtFileOfInterest.latLonToIndex(hgtAreaOfInterest.getUpperLeft())
                var lowerRightIndex:(Int, Int) = hgtFileOfInterest.latLonToIndex(hgtAreaOfInterest.getLowerRight())
                
                // the files are enumerated from top to bottom, left to right, so we need to flip the yIndex
                upperLeftIndex.1 = hgtFileOfInterest.getResolution() - upperLeftIndex.1
                lowerRightIndex.1 = hgtFileOfInterest.getResolution() - lowerRightIndex.1
                
                
                let data = NSData(contentsOfURL: hgtFileOfInterest.path)!
                
                NSLog("data.length \(data.length)")
                
                let dataRange = NSRange(location: 0, length: data.length)
                var elevation = [Int16](count: data.length, repeatedValue: Int16(Srtm.DATA_VOID))
                data.getBytes(&elevation, range: dataRange)
                
                
            }
        }
        
        
        
    
//    
//        var path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String

//        
//        
//        var row = 0
//        var column = 0
//        for cell in 0 ..< data.length {
//            elevationMatrix[row][column] = Int(elevation[cell].bigEndian)
//            //print(elevationMatrix[row][column])
//            column += 1
//            
//            if column >= Srtm3.MAX_SIZE {
//                column = 0
//                row += 1
//            }
//            
//            if row >= Srtm3.MAX_SIZE {
//                break
//            }
//        }

        
        return ElevationDataGrid(elevationData: elevationData, boundingBoxAreaExtent: griddedAxisOrientedBoundingBox, resolution: resolutioni)
    }
}