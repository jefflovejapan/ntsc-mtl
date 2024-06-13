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
        var effect: NTSCEffect = .default
        effect.inputLumaFilter = .notch
        effect.filterType = .butterworth
        effect.chromaLowpassIn = .full
        effect.chromaLowpassOut = .none
        effect.headSwitching?.midLine = nil
        effect.headSwitching?.offset = 32
        effect.headSwitching?.height = 64
        effect.headSwitching?.horizShift = 10
        effect.snowIntensity = 10
        effect.snowAnisotropy = 10
        effect.chromaPhaseError = 5
        self.filter = try! NTSCTextureFilter(effect: effect, device: device, context: ciContext)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private func setupCamera() {
//        captureSession.sessionPreset = .hd1920x1080
        captureSession.sessionPreset = .vga640x480
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
