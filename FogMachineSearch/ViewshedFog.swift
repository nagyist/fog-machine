//
//  ViewshedFog.swift
//  FogMachineSearch
//
//  Created by Chris Wasko on 11/18/15.
//  Copyright © 2015 NGA. All rights reserved.
//

import UIKit
import MapKit

public class ViewshedFog: NSObject {
    
    var elevation: [[Double]]
    var obsX: Int
    var obsY: Int
    var obsHeight: Int
    var viewRadius: Int
    var numberOfQuadrants: Int
    var whichQuadrant: Int
    
    
    init(elevation: [[Double]], observer: Observer, numberOfQuadrants: Int, whichQuadrant: Int) {
        self.elevation = elevation
        self.obsX = observer.x
        self.obsY = observer.y
        self.obsHeight = observer.height
        self.viewRadius = observer.radius
        self.numberOfQuadrants = numberOfQuadrants
        self.whichQuadrant = whichQuadrant
    }
    
    
    
    public func viewshedParallel() -> [[Double]] {
        
        var viewshedMatrix = [[Double]](count:Srtm3.MAX_SIZE, repeatedValue:[Double](count:Srtm3.MAX_SIZE, repeatedValue:0))
        
        let perimeter:[(x:Int, y:Int)] = getPerimeter(obsX, inY: obsY, radius: viewRadius,
            numberOfQuadrants: numberOfQuadrants, whichQuadrant: whichQuadrant)
        
        for (x, y) in perimeter {
            let bresenham = Bresenham()
            let bresResults:[(x:Int, y:Int)] = bresenham.findLine(obsX, y1: obsY, x2: x, y2: y)
            
            
            var greatestSlope = -Double.infinity
            
            for (x2, y2) in bresResults {
                
                if (x2 > 0 && y2 > 0) && (x2 < Srtm3.MAX_SIZE && y2 < Srtm3.MAX_SIZE) {
                    let zk:Double = elevation[obsX][obsY]
                    let zi:Double = elevation[x2][y2]
                    
                    let opposite = ( zi - (zk + Double(obsHeight)) )
                    let adjacent = sqrt( pow(Double(x2 - obsX), 2) + pow(Double(y2 - obsY), 2) )
                    let angle:Double = (Double(opposite)/Double(adjacent)) // for the actual angle use atan()
                    
                    if (angle < greatestSlope) {
                        //hidden
                        viewshedMatrix[x2 - 1][y2 - 1] = 0
                    } else {
                        greatestSlope = angle
                        //visible
                        viewshedMatrix[x2 - 1][y2 - 1] = 1
                    }
                }
                
            }
            
        }
        
        viewshedMatrix[obsX - 1][obsY - 1] = -1 // mark observer cell as unique
        
        return viewshedMatrix
        
    }
    
    

    
    // Returns an array of tuple (x,y) for the perimeter of the region based on the observer point and the radius
    // Supports single, double, or quadriple phones based on the number of quadrants (1, 2, or 4)
    private func getPerimeter(inX: Int, inY: Int, radius: Int, numberOfQuadrants: Int, whichQuadrant: Int) -> [(x:Int,y:Int)] {
        //let size = (radius * 2 + 1) * 4 - 4
        //Perimeter goes clockwise from the lower left coordinate
        
        var perimeter:[(x:Int, y:Int)] = []
        
        if (numberOfQuadrants == 1) {
            
            
            //lower left to top left
            for(var a = inX - radius; a <= inX + radius; a++) {
                perimeter.append((a, inY - radius))
            }
            
            //top left to top right (excludes corners)
            for(var b = inY - radius + 1; b < inY + radius; b++) {
                perimeter.append((inX + radius, b))
            }
            
            //top right to lower right
            for(var a = inX + radius; a >= inX - radius; a--) {
                perimeter.append((a, inY + radius))
            }
            
            //lower right to lower left (excludes corners)
            for(var b = inY + radius - 1; b > inY - radius; b--) {
                perimeter.append((inX - radius, b))
            }
            
            
        } else if (numberOfQuadrants == 2) {
            
            if (whichQuadrant == 1) {
                //lower left to top left
                for(var a = inX - radius; a <= inX + radius; a++) {
                    perimeter.append((a, inY - radius))
                }
                
                //top left to top right (excludes corners)
                for(var b = inY - radius + 1; b < inY + radius; b++) {
                    perimeter.append((inX + radius, b))
                }
                
                
            } else if (whichQuadrant == 2) {
                //top right to lower right
                for(var a = inX + radius; a >= inX - radius; a--) {
                    perimeter.append((a, inY + radius))
                }
                
                //lower right to lower left (excludes corners)
                for(var b = inY + radius - 1; b > inY - radius; b--) {
                    perimeter.append((inX - radius, b))
                }
                
            }
            
            
            
        } else if (numberOfQuadrants == 4) {
            
            
            if (whichQuadrant == 1) {
                //lower left to top left
                for(var a = inX - radius; a <= inX + radius; a++) {
                    perimeter.append((a, inY - radius))
                }
                
            } else if (whichQuadrant == 2) {
                //top left to top right (excludes corners)
                for(var b = inY - radius + 1; b < inY + radius; b++) {
                    perimeter.append((inX + radius, b))
                }
                
            } else if (whichQuadrant == 3) {
                //top right to lower right
                for(var a = inX + radius; a >= inX - radius; a--) {
                    perimeter.append((a, inY + radius))
                }
                
            } else if (whichQuadrant == 4) {
                //lower right to lower left (excludes corners)
                for(var b = inY + radius - 1; b > inY - radius; b--) {
                    perimeter.append((inX - radius, b))
                }
                
            }
            
        }
        
        //dump(perimeter)
        return perimeter
    }
    
    
    private func displayMatrix(matrix: [[Double]]) {
        for x in matrix.reverse() {
            print("\(x)")
        }
    }
    
    
}