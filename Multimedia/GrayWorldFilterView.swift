//
//  RobastFilterView.swift
//  Multimedia
//
//  Created by Alexey Voronov on 21/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit

class GrayWorldFilterView: FilterView {
    
    var histogramR: [UInt32] = [UInt32](repeating: 0, count: 256)
    var histogramG: [UInt32] = [UInt32](repeating: 0, count: 256)
    var histogramB: [UInt32] = [UInt32](repeating: 0, count: 256)
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        parametrs = ["red histogram", "green histogram", "blue histogram", "input texture"]
    }
    
    override func processImage() {
        grayWorld()
        super.processImage()
    }
    
    override func reloadInputTextures() {
        super.reloadInputTextures()
        if let inputTexture = parentFilter4?.outImageTexture {
            inImageTexture = inputTexture
        }
    }
    
    func grayWorld() {
        histogramR = parentFilter?.histogram ?? []
        histogramG = parentFilter2?.histogram ?? []
        histogramB = parentFilter3?.histogram ?? []
        
        
        let allCount = Double(histogramR.reduce(0, +))
        var redSum = 0.0
        for (intensity, count) in histogramR.enumerated() {
            redSum += Double(intensity) / 255.0 * Double(count) / allCount
        }
        let dRed = redSum
        
        var greenSum = 0.0
        for (intensity, count) in histogramG.enumerated() {
            greenSum += Double(intensity) / 255.0 * Double(count) / allCount
        }
        let dGreen = greenSum
        
        var blueSum = 0.0
        for (intensity, count) in histogramB.enumerated() {
            blueSum += Double(intensity) / 255.0 * Double(count) / allCount
        }
        let dBlue = blueSum
        
        let avg = (dRed + dBlue + dGreen) / 3
        
        value = Float(avg/dRed)
        value2 = Float(avg/dGreen)
        value3 = Float(avg/dBlue)
    }
    
    
}
