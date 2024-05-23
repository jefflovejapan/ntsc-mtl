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
    private var filter: CIFilter
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    init(filter: CIFilter) {
        self.filter = filter
        super.init(frame: .zero)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd4K3840x2160
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        captureSession.addOutput(videoOutput)
        
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        
        // Apply CIFilter
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let filteredImage = filter.outputImage else { return }
        
        // Render the filtered image to the preview layer
        let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent)
        DispatchQueue.main.async {
            self.layer.contents = cgImage
        }
    }
}

struct CameraView: UIViewRepresentable {
    @State var filter: CIFilter
    
    init(filter: CIFilter) {
        _filter = State(initialValue: filter)
    }
    
    func makeUIView(context: Context) -> CameraUIView {
        return CameraUIView(filter: filter)
    }
    
    func updateUIView(_ uiView: CameraUIView, context: Context) {}
}
