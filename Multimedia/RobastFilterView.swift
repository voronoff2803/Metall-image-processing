//
//  RobastFilterView.swift
//  Multimedia
//
//  Created by Alexey Voronov on 21/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit

class RobastFilterView: FilterView {
    
    override func setup() {
        super.setup()
        
        slider.isHidden = false
        slider.maximumValue = 0.10
        slider.minimumValue = 0.05
    }
    
    override func processImage() {
        linarCorrection()
        super.processImage()
    }
    
    func linarCorrection() {
        let inHistogram = parentFilter!.histogram
        var sum: UInt32 = 0
        
        for i in inHistogram {
            sum += i
        }
        let treshold = Float(sum) * slider.value
        var min: Float = 0.0
        var max: Float = 1.0
        
        var minSum: UInt32 = 0
        for (index, i) in inHistogram.enumerated() {
            minSum += i
            if minSum > UInt32(treshold) {
                min = Float(index) / 255
                break
            }
        }
        
        var maxSum: UInt32 = 0
        for (index, i) in inHistogram.reversed().enumerated() {
            maxSum += i
            if maxSum > UInt32(treshold) {
                max = Float(inHistogram.count - 1 - index) / 255
                break
            }
        }
        
        self.value = min
        self.value2 = max
        
    }
}
