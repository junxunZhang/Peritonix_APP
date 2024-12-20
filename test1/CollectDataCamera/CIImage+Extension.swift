//
//  CIImage+Extension.swift
//  Peritonix
//
//  Created by 張晉薰 on 2024/9/11.
//

import CoreImage

extension CIImage {
    
    var cgImage: CGImage? {
        let ciContext = CIContext()
        
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else {
            return nil
        }
        
        return cgImage
    }
    
}

