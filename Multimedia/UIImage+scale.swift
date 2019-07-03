//
//  UIImage+scale.swift
//  Multimedia
//
//  Created by Alexey Voronov on 21/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit
import Metal
import MetalKit

extension UIImage
{
    func imageWithSize(size:CGSize) -> UIImage
    {
        var scaledImageRect = CGRect.zero
        
        let aspectWidth:CGFloat = size.width / self.size.width
        let aspectHeight:CGFloat = size.height / self.size.height
        
        //max - scaleAspectFill | min - scaleAspectFit
        let aspectRatio:CGFloat = max(aspectWidth, aspectHeight)
        
        scaledImageRect.size.width = self.size.width * aspectRatio
        scaledImageRect.size.height = self.size.height * aspectRatio
        scaledImageRect.origin.x = (size.width - scaledImageRect.size.width) / 2.0
        scaledImageRect.origin.y = (size.height - scaledImageRect.size.height) / 2.0
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        self.draw(in: scaledImageRect)
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
}





