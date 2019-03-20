//
//  DepthImageFilters.swift
//  DepthVideo
//
//  Created by Mobdev125 on 3/20/19.
//  Copyright © 2019 Mobdev125. All rights reserved.
//

import UIKit

enum MaskParams {
    static let slope: CGFloat = 4.0
    static let sharpSlope: CGFloat = 10.0
    static let width: CGFloat = 0.1
}

class DepthImageFilters {
    
    func createHighPassMask(for depthImage: CIImage,
                            withFocus focus: CGFloat,
                            andScale scale: CGFloat,
                            isSharp: Bool = false) -> CIImage {
        
        let s = isSharp ? MaskParams.sharpSlope : MaskParams.slope
        let filterWidth =  2 / s + MaskParams.width
        let b = -s * (focus - filterWidth / 2)
        
        let mask = depthImage
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: s, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: s, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: s, w: 0),
                "inputBiasVector": CIVector(x: b, y: b, z: b, w: 0)])
            .applyingFilter("CIColorClamp")
            .applyingFilter("CIBicubicScaleTransform",
                            parameters: ["inputScale": scale])
        
        return mask
    }
    
    func createBandPassMask(for depthImage: CIImage,
                            withFocus focus: CGFloat,
                            andScale scale: CGFloat) -> CIImage {
        
        let s1 = MaskParams.slope
        let s2 = -MaskParams.slope
        let filterWidth =  2 / MaskParams.slope + MaskParams.width
        let b1 = -s1 * (focus - filterWidth / 2)
        let b2 = -s2 * (focus + filterWidth / 2)
        
        let mask0 = depthImage
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: s1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: s1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: s1, w: 0),
                "inputBiasVector": CIVector(x: b1, y: b1, z: b1, w: 0)])
            .applyingFilter("CIColorClamp")
        
        let mask1 = depthImage
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: s2, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: s2, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: s2, w: 0),
                "inputBiasVector": CIVector(x: b2, y: b2, z: b2, w: 0)])
            .applyingFilter("CIColorClamp")
        
        let combinedMask = mask0.applyingFilter("CIDarkenBlendMode",
                                                parameters: ["inputBackgroundImage": mask1])
        
        let mask = combinedMask.applyingFilter("CIBicubicScaleTransform",
                                               parameters: ["inputScale": scale])
        
        return mask
    }
    
    func comic(image: CIImage, mask: CIImage) -> CIImage {
        let bg = image.applyingFilter("CIComicEffect")
        let filtered = image.applyingFilter("CIBlendWithMask",
                                            parameters: ["inputBackgroundImage": bg,
                                                         "inputMaskImage": mask])
        return filtered
    }
    func greenScreen(image: CIImage, background: CIImage, mask: CIImage) -> CIImage {
        let crop = CIVector(x: 0,
                            y: 0,
                            z: image.extent.size.width,
                            w: image.extent.size.height)
        let croppedBG = background.applyingFilter("CICrop",
                                                  parameters: ["inputRectangle": crop])
        let filtered = image.applyingFilter("CIBlendWithMask",
                                            parameters: ["inputBackgroundImage": croppedBG,
                                                         "inputMaskImage": mask])
        return filtered
    }
    
    func blur(image: CIImage, mask: CIImage) -> CIImage {
        let blurRadius: CGFloat = 10
        let crop = CIVector(x: 0,
                            y: 0,
                            z: image.extent.size.width,
                            w: image.extent.size.height)
        let invertedMask = mask.applyingFilter("CIColorInvert")
        let blurred = image.applyingFilter("CIMaskedVariableBlur",
                                           parameters: ["inputMask": invertedMask,
                                                        "inputRadius": blurRadius])
        let filtered = blurred.applyingFilter("CICrop",
                                              parameters: ["inputRectangle": crop])
        return filtered
    }

}
