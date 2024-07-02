//
//  Resolution.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-15.
//

import Foundation
import AVFoundation

public enum Resolution: String, Identifiable, CaseIterable {
    case res4K
    case res1080p
    case res720p
    case resVGA
    
    public var id: String {
        rawValue
    }
    
    public var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .resVGA:
            return .vga640x480
        case .res1080p:
            return .hd1920x1080
        case .res720p:
            return .hd1280x720
        case .res4K:
            return .hd4K3840x2160
        }
    }
}
