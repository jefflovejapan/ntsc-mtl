//
//  CameraView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import AVFoundation
import CoreImage

class CameraUIView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private var filter: NTSCFilter!
    private let previewLayer = AVCaptureVideoPreviewLayer()
    var isFilterEnabled: Bool
    
    init(isFilterEnabled: Bool) {
        self.isFilterEnabled = isFilterEnabled
        super.init(frame: .zero)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd1920x1080
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        captureSession.addInput(input)
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        captureSession.addOutput(videoOutput)
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        if filter == nil {
            var effect = NTSCEffect.default
            effect.chromaLowpassIn = .light
//            effect.inputLumaFilter = .box
//            effect.chromaLowpassIn = .light
            self.filter = NTSCFilter(size: ciImage.extent.size, effect: effect)
        }
        
        // Apply CIFilter
        let outputImage: CIImage?
        if isFilterEnabled {
            filter.inputImage = ciImage
            outputImage = filter.outputImage
        } else {
            outputImage = ciImage
        }
        
        guard let outputImage else {
            return
        }
        let orientedImage = outputImage.oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))
        
        // Render the filtered image to the preview layer
        guard let cgImage = ciContext.createCGImage(orientedImage, from: orientedImage.extent) else {
            return
        }
        DispatchQueue.main.async {
            self.layer.contents = cgImage
        }
    }
}

struct CameraView: UIViewRepresentable {
    @Binding var enableFilter: Bool
    
    init(enableFilter: Binding<Bool>) {
        _enableFilter = enableFilter
    }
    
    func makeUIView(context: Context) -> CameraUIView {
        return CameraUIView(isFilterEnabled: enableFilter)
    }
    
    func updateUIView(_ uiView: CameraUIView, context: Context) {
        uiView.isFilterEnabled = enableFilter
    }
}
