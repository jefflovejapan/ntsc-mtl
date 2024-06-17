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
    let filter: NTSCTextureFilter!
    
    var isFilterEnabled: Bool
    var lastImage: CIImage?
    var sessionPreset: AVCaptureSession.Preset = .vga640x480 {
        didSet {
            captureSession.sessionPreset = sessionPreset
        }
    }
    
    init(isFilterEnabled: Bool, effect: NTSCEffect) throws {
        let device = MTLCreateSystemDefaultDevice()!
        self.device = device
        let commandQueue = device.makeCommandQueue()!
        self.commandQueue = commandQueue
        let context = CIContext(mtlCommandQueue: commandQueue)
        self.ciContext = context
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        self.mtkView = mtkView
        self.isFilterEnabled = isFilterEnabled
        self.filter = try NTSCTextureFilter(effect: effect, device: device, ciContext: context)
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
        captureSession.sessionPreset = sessionPreset
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: /*.front*/.back)
        guard let captureDevice = discoverySession.devices.first else {
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
            .oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))

        self.lastImage = ciImage
        DispatchQueue.main.async {
            self.mtkView.setNeedsDisplay()
        }
    }
}

struct CameraView: UIViewRepresentable {
    @Binding var enableFilter: Bool
    @Binding var resolution: Resolution
    @Bindable var effect: NTSCEffect
    
    init(enableFilter: Binding<Bool>, resolution: Binding<Resolution>, effect: NTSCEffect) {
        _enableFilter = enableFilter
        _resolution = resolution
        self.effect = effect
    }
    
    func makeUIView(context: Context) -> CameraUIView {
        return try! CameraUIView(isFilterEnabled: enableFilter, effect: effect)
    }
    
    func updateUIView(_ uiView: CameraUIView, context: Context) {
        uiView.isFilterEnabled = enableFilter
        uiView.sessionPreset = resolution.sessionPreset
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
        
        let widthMultiple = dSize.width / outputImage.extent.size.width
        let heightMultiple = dSize.height / outputImage.extent.size.height
        let scaleFactor = max(widthMultiple, heightMultiple)
        let scaledImage = outputImage.transformed(by: CGAffineTransform.init(scaleX: scaleFactor, y: scaleFactor))
        
        do {
            try ciContext.startTask(toRender: scaledImage, to: destination)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        } catch {
            print("Error starting render task: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("mtkView will change drawable size to \(size)")
    }
}
