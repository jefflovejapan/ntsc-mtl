//
//  CameraView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import AVFoundation
import CoreImage
import MetalKit

class CameraUIView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext: CIContext
    private let device: MTLDevice
    private let mtkView: MTKView
    private let commandQueue: MTLCommandQueue
    private var filter: NTSCTextureFilter!
    
    var isFilterEnabled: Bool
    var lastImage: CIImage?
    
    init(isFilterEnabled: Bool) {
        let device = MTLCreateSystemDefaultDevice()!
        self.device = device
        let commandQueue = device.makeCommandQueue()!
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlCommandQueue: commandQueue)
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        self.mtkView = mtkView
        self.isFilterEnabled = isFilterEnabled
        super.init(frame: .zero)
        self.mtkView.delegate = self
        addSubview(self.mtkView)
        self.mtkView.translatesAutoresizingMaskIntoConstraints = false
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[mtk]|", metrics: nil, views: ["mtk": mtkView])
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtk]|", metrics: nil, views: ["mtk": mtkView])
        NSLayoutConstraint.activate(hConstraints + vConstraints)
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
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.automaticallyAdjustsVideoHDREnabled = false
            captureDevice.isVideoHDREnabled = false
            captureDevice.unlockForConfiguration()
        } catch {
            print("Couldn't turn off HDR: \(error)")
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
        self.lastImage = ciImage
        if filter == nil {
            self.filter = try! NTSCTextureFilter(device: device, context: ciContext)
            self.filter.effect.inputLumaFilter = .box
        }
        DispatchQueue.main.async {
            self.mtkView.setNeedsDisplay()
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

extension CameraUIView: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard let lastImage else {
            return
        }
        guard let drawable = view.currentDrawable else {
            return
        }
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }
        let dSize = view.drawableSize
        let destination = CIRenderDestination(
            width: Int(dSize.width),
            height: Int(dSize.height),
            pixelFormat: view.colorPixelFormat, 
            commandBuffer: commandBuffer,
            mtlTextureProvider: {
                drawable.texture
            })
        
        // Apply CIFilter
        let outputImage: CIImage?
        if isFilterEnabled {
            filter.inputImage = lastImage
            outputImage = filter.outputImage
        } else {
            outputImage = lastImage
        }
        
        guard let outputImage else {
            return
        }
        let orientedImage = outputImage.oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))
        
        do {
            try ciContext.startTask(toRender: orientedImage, to: destination)
            commandBuffer.present(drawable)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        } catch {
            print("Error starting render task: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("mtkView will change drawable size to \(size)")
    }
}
